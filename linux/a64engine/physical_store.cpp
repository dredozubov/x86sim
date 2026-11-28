// SPDX-License-Identifier: GPL-3.0-or-later
#include "physical_store.h"
#include "cache_key.h"

#include <dynarmic/interface/A64/physical_ir_cache.h>
#include <openssl/evp.h>
#include <sqlite3.h>

#include <array>
#include <atomic>
#include <cerrno>
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
#include <span>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
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
    struct Entry { Bytes data; IRCacheSource source; };
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
    std::atomic<uint64_t> memory_hits{0}, disk_hits{0};
    uint64_t lookups = 0, stores = 0, written = 0;

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

    bool keep(const Key& key, std::span<const uint8_t> data, IRCacheSource source) {
        auto it = records.find(key);
        const size_t old = it == records.end() ? 0 : it->second.data.size();
        if ((it == records.end() && records.size() >= entry_limit) ||
            total - old + data.size() > memory_limit) return false;
        auto& entry = records[key];
        entry.data.assign(data.begin(), data.end());
        entry.source = source;
        total = total - old + data.size();
        return true;
    }

public:
    explicit RecordStore(const char* directory) {
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
             "CREATE TABLE IF NOT EXISTS blocks(k BLOB PRIMARY KEY, ir BLOB NOT NULL, hash BLOB NOT NULL) WITHOUT ROWID");
        const auto query = "SELECT k,ir,hash FROM blocks LIMIT " + std::to_string(entry_limit);
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
            if (!keep(key, data, IRCacheSource::Disk)) break;
        }
        insert = prepare("INSERT OR REPLACE INTO blocks(k,ir,hash) VALUES(?,?,?)");
        sqlite3_busy_timeout(db.get(), 0); // Concurrent learners can always use their VM-local copy.
    }

    ~RecordStore() override {
        commit();
        std::fprintf(stderr, "a64engine memory_hits=%llu disk_hits=%llu lookups=%llu stores=%llu written=%llu\n",
            (unsigned long long)memory_hits.load(), (unsigned long long)disk_hits.load(),
            (unsigned long long)lookups, (unsigned long long)stores, (unsigned long long)written);
    }
    IRCacheSource Lookup(const PhysicalIRKey& key, Bytes& record) override {
        std::lock_guard lock(mutex);
        ++lookups;
        const auto k = key_bytes(key);
        auto& slot = recent_slot(k);
        if (!slot || slot->first != k) {
            auto it = records.find(k);
            if (it == records.end()) return IRCacheSource::Miss;
            slot = &*it;
        }
        record = slot->second.data;
        return slot->second.source;
    }
    void Hit(IRCacheSource source) override {
        if (source == IRCacheSource::Disk) ++disk_hits;
        if (source == IRCacheSource::Memory) ++memory_hits;
    }
    void InvalidatePage(uint64_t pa) override {
        std::lock_guard lock(mutex);
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
        if (!transaction) {
            if (sqlite3_exec(db.get(), "BEGIN IMMEDIATE", nullptr, nullptr, nullptr) != SQLITE_OK) return;
            transaction = true;
        }
        auto* q = insert.get();
        const auto hash = digest(key, record);
        const bool saved = sqlite3_bind_blob(q, 1, key.data(), sizeof(key), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_bind_blob(q, 2, record.data(), static_cast<int>(record.size()), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_bind_blob(q, 3, hash.data(), sizeof(hash), SQLITE_STATIC) == SQLITE_OK &&
                           sqlite3_step(q) == SQLITE_DONE;
        sqlite3_reset(q);
        sqlite3_clear_bindings(q);
        if (saved) ++pending;
        // Release the writer lock even if the DB filled before a batch completed.
        if (!saved || pending == 1024) commit();
    }
};

} // namespace

std::shared_ptr<Dynarmic::A64::PhysicalIRCache> a64engine::open_physical_store(const char* directory) {
    return std::make_shared<RecordStore>(directory);
}
