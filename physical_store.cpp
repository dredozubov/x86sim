// SPDX-License-Identifier: GPL-3.0-or-later
#include "physical_store.h"
#include "cache_key.h"

#include <dynarmic/interface/A64/physical_ir_cache.h>
#include <openssl/evp.h>
#include <sqlite3.h>

#include <array>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <cpuid.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <link.h>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <span>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_map>
#include <vector>

namespace {
using namespace Dynarmic::A64;
using Key = std::array<uint64_t, 4>;
using Bytes = std::vector<uint8_t>;
constexpr size_t record_limit = 1 << 20;
constexpr size_t memory_limit = 128 << 20;
constexpr size_t entry_limit = 524288;

Key key_bytes(const PhysicalIRKey& k) {
    return {k.guest_pa, k.location, k.pac_profile, k.page_mode};
}

using Digest = std::array<unsigned char, 32>;
Digest digest(const Key& key, std::span<const uint8_t> data) {
    std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)> ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    Digest result;
    unsigned size = 0;
    if (!ctx || !EVP_DigestInit_ex(ctx.get(), EVP_sha256(), nullptr) ||
        !EVP_DigestUpdate(ctx.get(), key.data(), sizeof(key)) ||
        !EVP_DigestUpdate(ctx.get(), data.data(), data.size()) ||
        !EVP_DigestFinal_ex(ctx.get(), result.data(), &size) || size != result.size())
        throw std::runtime_error("unable to hash a64engine record");
    return result;
}

// Include the running library's build ID, even if the file was replaced after dlopen.
int build_id(dl_phdr_info* info, size_t, void* output) {
    const auto address = reinterpret_cast<uintptr_t>(&build_id);
    bool owner = false;
    for (size_t i = 0; i < info->dlpi_phnum; ++i) {
        const auto& ph = info->dlpi_phdr[i];
        const uintptr_t start = info->dlpi_addr + ph.p_vaddr;
        if (ph.p_type == PT_LOAD && address >= start && address - start < ph.p_memsz) owner = true;
    }
    if (!owner) return 0;
    for (size_t i = 0; i < info->dlpi_phnum; ++i) {
        const auto& ph = info->dlpi_phdr[i];
        if (ph.p_type != PT_NOTE) continue;
        auto* p = reinterpret_cast<const uint8_t*>(info->dlpi_addr + ph.p_vaddr);
        auto* end = p + ph.p_filesz;
        while (size_t(end - p) >= sizeof(ElfW(Nhdr))) {
            ElfW(Nhdr) note;
            std::memcpy(&note, p, sizeof(note));
            p += sizeof(note);
            const auto names = (size_t(note.n_namesz) + 3) & ~size_t{3};
            const auto desc = (size_t(note.n_descsz) + 3) & ~size_t{3};
            if (names + desc > size_t(end - p)) break;
            if (note.n_type == NT_GNU_BUILD_ID && note.n_namesz == 4 &&
                std::memcmp(p, "GNU", 4) == 0 && note.n_descsz && note.n_descsz <= 64) {
                auto& id = *static_cast<Bytes*>(output);
                id.assign(p + names, p + names + note.n_descsz);
                return 1;
            }
            p += names + desc;
        }
    }
    return 1;
}

std::string store_name() {
    Bytes image;
    dl_iterate_phdr(build_id, &image);
    if (image.empty()) throw std::runtime_error("a64engine requires an ELF build ID");
    // IR polyfills depend on the host instruction set and the OS-enabled register state.
    unsigned a, b, c, d;
    std::array<unsigned, 10> features{};
    if (!__get_cpuid(1, &a, &b, &c, &d)) throw std::runtime_error("missing x86 feature information");
    features[0] = a;
    features[1] = c;
    features[2] = d;
    if (c & bit_OSXSAVE) asm("xgetbv" : "=a"(features[3]), "=d"(features[4]) : "c"(0));
    if (__get_cpuid_count(7, 0, &a, &b, &c, &d)) {
        features[5] = b;
        features[6] = c;
        features[7] = d;
    }
    if (__get_cpuid(0x80000001u, &a, &b, &c, &d)) {
        features[8] = c;
        features[9] = d;
    }
    const auto* bytes = reinterpret_cast<const uint8_t*>(features.data());
    image.insert(image.end(), bytes, bytes + sizeof(features));
    return "ir-" + a64engine::cache_key(image, 1) + ".db";
}

struct DbCloser { void operator()(sqlite3* p) const { sqlite3_close_v2(p); } };
struct StmtCloser { void operator()(sqlite3_stmt* p) const { sqlite3_finalize(p); } };
using Statement = std::unique_ptr<sqlite3_stmt, StmtCloser>;

class RecordStore final : public PhysicalIRCache {
    struct Entry {
        Bytes data;
        IRCacheSource source{};
        NativeReuse reuse = NativeReuse::Unknown, saved_reuse = NativeReuse::Unknown;
    };
    using Records = std::map<Key, Entry>;
    Records records;
    // References into std::map survive inserts. InvalidatePage clears references
    // before erasing nodes. All accesses are under the VM's cache mutex.
    std::array<const Records::value_type*, 8192> recent{};
    auto& recent_slot(const Key& key) {
        const auto index = (key[0] >> 2) ^ (key[0] >> 15) ^ (key[1] >> 48) ^ key[2] ^ key[3];
        return recent[index & (recent.size() - 1)];
    }
    size_t total = 0;
    std::mutex mutex;
    std::unique_ptr<sqlite3, DbCloser> db;
    Statement insert;
    unsigned pending = 0;
    bool transaction = false;
    std::atomic<uint64_t> memory_hits{0}, disk_hits{0}, native_replays{0};
    uint64_t lookups = 0, stores = 0, written = 0;

    // Simulate one demand read per PA page against the immutable training set.
    // Records learned in this run require no disk lookup.
    struct PageDemand {
        struct Page { size_t rows = 0, bytes = 0; bool visited = false; };
        std::unordered_map<uint64_t, Page> pages;
        size_t reads = 0, empty = 0, rows = 0, bytes = 0;

        void probe(uint64_t pa) {
            auto& page = pages[pa >> 12];
            if (page.visited) return;
            page.visited = true;
            ++reads;
            if (!page.rows) ++empty;
            rows += page.rows;
            bytes += page.bytes;
        }

        void report() const {
            const auto stamp = std::chrono::steady_clock::now().time_since_epoch();
            const auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(stamp).count();
            std::fprintf(stderr, "a64engine-page-demand mono_ns=%lld reads=%zu empty=%zu rows=%zu ir_bytes=%zu\n",
                         (long long)ns, reads, empty, rows, bytes);
        }
    };
    std::optional<PageDemand> page_demand;

    void exec(const char* sql) {
        if (sqlite3_exec(db.get(), sql, nullptr, nullptr, nullptr) != SQLITE_OK)
            throw std::runtime_error(sqlite3_errmsg(db.get()));
    }
    Statement prepare(const char* sql) {
        sqlite3_stmt* statement = nullptr;
        if (sqlite3_prepare_v2(db.get(), sql, -1, &statement, nullptr) != SQLITE_OK)
            throw std::runtime_error(sqlite3_errmsg(db.get()));
        return Statement(statement);
    }

    void commit() {
        if (!transaction) return;
        if (sqlite3_exec(db.get(), "COMMIT", nullptr, nullptr, nullptr) == SQLITE_OK)
            written += pending;
        else
            sqlite3_exec(db.get(), "ROLLBACK", nullptr, nullptr, nullptr);
        pending = 0;
        transaction = false;
    }

    bool persist(const Key& key, const Entry& entry) {
        if (!transaction) {
            if (sqlite3_exec(db.get(), "BEGIN IMMEDIATE", nullptr, nullptr, nullptr) != SQLITE_OK) return false;
            transaction = true;
        }
        auto* q = insert.get();
        const auto& record = entry.data;
        const auto hash = digest(key, record);
        const bool saved = sqlite3_bind_blob(q, 1, key.data(), sizeof(key), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_bind_blob(q, 2, record.data(), static_cast<int>(record.size()), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_bind_blob(q, 3, hash.data(), sizeof(hash), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_bind_int(q, 4, static_cast<int>(entry.reuse)) == SQLITE_OK &&
                           sqlite3_step(q) == SQLITE_DONE;
        sqlite3_reset(q);
        sqlite3_clear_bindings(q);
        if (saved) ++pending;
        // Release the writer lock even if the DB filled before a batch completed.
        if (!saved || pending == 1024) commit();
        return saved;
    }

    bool keep(const Key& key, std::span<const uint8_t> data, IRCacheSource source, NativeReuse reuse = NativeReuse::Unknown) {
        auto it = records.lower_bound(key);
        const bool found = it != records.end() && it->first == key;
        const size_t old = found ? it->second.data.size() : 0;
        if ((!found && records.size() >= entry_limit) ||
            total - old + data.size() > memory_limit) return false;
        if (!found) it = records.emplace_hint(it, key, Entry{});
        auto& entry = it->second;
        entry.data.assign(data.begin(), data.end());
        entry.source = source;
        entry.reuse = entry.saved_reuse = reuse;
        total = total - old + data.size();
        return true;
    }

public:
    explicit RecordStore(const char* directory) {
        using Clock = std::chrono::steady_clock;
        const bool profile = std::getenv("X86XNU_A64_CACHE_PROFILE") != nullptr;
        const auto start = profile ? Clock::now() : Clock::time_point{};
        if (mkdir(directory, 0700) && errno != EEXIST)
            throw std::runtime_error("cannot create a64engine directory");
        struct stat st{};
        if (lstat(directory, &st) || !S_ISDIR(st.st_mode) || st.st_uid != geteuid() || (st.st_mode & 077))
            throw std::runtime_error("a64engine requires a private owner-only directory");
        auto path = std::filesystem::path(directory) / store_name();
        const int fd = open(path.c_str(), O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0600);
        if (fd < 0) throw std::runtime_error("cannot open a64engine database");
        const bool valid = !fstat(fd, &st) && S_ISREG(st.st_mode) && st.st_uid == geteuid() &&
                           !(st.st_mode & 077) && st.st_nlink == 1 && st.st_size <= (512ll << 20);
        close(fd);
        if (!valid) throw std::runtime_error("invalid a64engine database ownership, size or file type");
        sqlite3* connection = nullptr;
        const int rc = sqlite3_open_v2(path.c_str(), &connection,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOFOLLOW | SQLITE_OPEN_NOMUTEX, nullptr);
        db.reset(connection);
        if (rc != SQLITE_OK) throw std::runtime_error("cannot initialize a64engine database");
        sqlite3_limit(db.get(), SQLITE_LIMIT_LENGTH, 2 * record_limit);
        sqlite3_busy_timeout(db.get(), 1000);
        exec("PRAGMA trusted_schema=OFF; PRAGMA max_page_count=65536;"
             "CREATE TABLE IF NOT EXISTS blocks(k BLOB PRIMARY KEY, ir BLOB NOT NULL, hash BLOB NOT NULL,"
             " reuse INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID");
        const auto has_reuse_column = [&] {
            auto columns = prepare("SELECT 1 FROM pragma_table_info('blocks') WHERE name='reuse'");
            return sqlite3_step(columns.get()) == SQLITE_ROW;
        };
        if (!has_reuse_column() &&
            sqlite3_exec(db.get(), "ALTER TABLE blocks ADD COLUMN reuse INTEGER NOT NULL DEFAULT 0", nullptr, nullptr, nullptr) != SQLITE_OK &&
            !has_reuse_column()) throw std::runtime_error(sqlite3_errmsg(db.get()));
        const auto query = "SELECT k,ir,hash,reuse FROM blocks LIMIT " + std::to_string(entry_limit);
        auto load = prepare(query.c_str());
        while (sqlite3_step(load.get()) == SQLITE_ROW) {
            const int len = sqlite3_column_bytes(load.get(), 1);
            if (sqlite3_column_bytes(load.get(), 0) != sizeof(Key) ||
                sqlite3_column_bytes(load.get(), 2) != sizeof(Digest) || len <= 0 || size_t(len) > record_limit)
                continue;
            Key key;
            std::memcpy(key.data(), sqlite3_column_blob(load.get(), 0), sizeof(key));
            std::span data(static_cast<const uint8_t*>(sqlite3_column_blob(load.get(), 1)), size_t(len));
            if (std::memcmp(digest(key, data).data(), sqlite3_column_blob(load.get(), 2), sizeof(Digest))) continue;
            const int level = sqlite3_column_int(load.get(), 3);
            const auto reuse = level >= 0 && level <= int(NativeReuse::Frequent) ? static_cast<NativeReuse>(level) : NativeReuse::Unknown;
            if (!keep(key, data, IRCacheSource::Disk, reuse)) break;
        }
        insert = prepare("INSERT OR REPLACE INTO blocks(k,ir,hash,reuse) VALUES(?,?,?,?)");
        sqlite3_busy_timeout(db.get(), 0); // Concurrent learners can always use their VM-local copy.
        if (profile) {
            const auto elapsed = std::chrono::duration<double>(Clock::now() - start).count();
            std::fprintf(stderr, "a64engine-load rows=%zu ir_bytes=%zu seconds=%.6f\n", records.size(), total, elapsed);
            if (!records.empty()) {
                page_demand.emplace();
                for (const auto& [key, entry] : records) {
                    auto& page = page_demand->pages[key[0] >> 12];
                    ++page.rows;
                    page.bytes += entry.data.size();
                }
            }
        }
    }

    ~RecordStore() override {
        if (page_demand) page_demand->report();
        // All vCPUs have released this VM by now. A disk sync on a live vCPU
        // could stall it while the guest owns a spinlock and time out a peer.
        try {
            for (const auto& [key, entry] : records) {
                if ((entry.source == IRCacheSource::Memory || entry.reuse != entry.saved_reuse) && !persist(key, entry)) break;
            }
        } catch (const std::exception& error) {
            std::fprintf(stderr, "a64engine cache save: %s\n", error.what());
        }
        commit();
        std::fprintf(stderr, "a64engine memory_hits=%llu disk_hits=%llu lookups=%llu stores=%llu written=%llu native_replays=%llu\n",
            (unsigned long long)memory_hits.load(), (unsigned long long)disk_hits.load(),
            (unsigned long long)lookups, (unsigned long long)stores, (unsigned long long)written,
            (unsigned long long)native_replays.load());
    }
    IRCacheSource Lookup(const PhysicalIRKey& key, Bytes& record) override {
        NativeReuse ignored{};
        return LookupWithReuse(key, record, ignored);
    }
    IRCacheSource LookupWithReuse(const PhysicalIRKey& key, Bytes& record, NativeReuse& reuse) override {
        std::lock_guard lock(mutex);
        reuse = NativeReuse::Unknown;
        ++lookups;
        if (page_demand && (lookups & ((1u << 17) - 1)) == 0) page_demand->report();
        const auto k = key_bytes(key);
        auto& slot = recent_slot(k);
        if (!slot || slot->first != k) {
            auto it = records.find(k);
            if (it == records.end()) {
                if (page_demand) page_demand->probe(key.guest_pa);
                return IRCacheSource::Miss;
            }
            slot = &*it;
        }
        if (page_demand && slot->second.source == IRCacheSource::Disk) page_demand->probe(key.guest_pa);
        reuse = slot->second.reuse;
        record = slot->second.data;
        return slot->second.source;
    }
    void ObserveNativeReuse(const PhysicalIRKey& key, NativeReuse reuse) override {
        std::lock_guard lock(mutex);
        auto it = records.find(key_bytes(key));
        if (it != records.end() && it->second.reuse < reuse) it->second.reuse = reuse;
    }
    void Hit(IRCacheSource source) override {
        if (source == IRCacheSource::Disk) ++disk_hits;
        if (source == IRCacheSource::Memory) ++memory_hits;
    }
    void NativeReplays(uint64_t hits) override { native_replays += hits; }
    void InvalidatePage(uint64_t pa) override {
        std::lock_guard lock(mutex);
        if (page_demand) page_demand->pages[pa >> 12].visited = true;
        const uint64_t page = pa & ~uint64_t{4095};
        auto it = records.lower_bound({page, 0, 0, 0});
        while (it != records.end() && it->first[0] - page < 4096) {
            auto& slot = recent_slot(it->first);
            if (slot == &*it) slot = nullptr;
            total -= it->second.data.size();
            it = records.erase(it);
        }
    }
    void Store(const PhysicalIRKey& physical, const Bytes& record) override {
        if (record.empty() || record.size() > record_limit) return;
        const Key key = key_bytes(physical);
        std::lock_guard lock(mutex);
        if (!keep(key, record, IRCacheSource::Memory)) return;
        ++stores;
    }
};

} // namespace

std::shared_ptr<Dynarmic::A64::PhysicalIRCache> a64engine::open_physical_store(const char* directory) {
    return std::make_shared<RecordStore>(directory);
}
