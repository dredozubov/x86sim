// SPDX-License-Identifier: 0BSD
#pragma once

#include <cstdint>
#include <vector>

namespace Dynarmic::A64 {

struct PhysicalIRKey {
    std::uint64_t guest_pa;
    std::uint64_t location;  // EL, FPCR and single-step mode. The PA supplies the block offset.
    std::uint64_t pac_profile;
    std::uint64_t page_mode;
    bool operator==(const PhysicalIRKey&) const = default;
};

enum class IRCacheSource { Miss,
                           Memory,
                           Disk };

enum class NativeReuse : std::uint8_t { Unknown, Repeated, Frequent };

// Returned records must originate from this engine build on a trusted host.
// The frontend additionally checks its full fetch and compilation context.
class PhysicalIRCache {
public:
    virtual ~PhysicalIRCache() = default;
    virtual IRCacheSource Lookup(const PhysicalIRKey&, std::vector<std::uint8_t>&) = 0;
    virtual void Store(const PhysicalIRKey&, const std::vector<std::uint8_t>&) = 0;
    virtual void Hit(IRCacheSource) = 0;
    virtual void InvalidatePage(std::uint64_t guest_pa) = 0;
    virtual void NativeReplays(std::uint64_t) {}
    virtual IRCacheSource LookupWithReuse(const PhysicalIRKey& key, std::vector<std::uint8_t>& out, NativeReuse& prior) {
        prior = NativeReuse::Unknown;
        return Lookup(key, out);
    }
    virtual void ObserveNativeReuse(const PhysicalIRKey&, NativeReuse) {}
    // A nonzero generation names these exact bytes for this cache's lifetime.
    virtual IRCacheSource LookupForEmission(const PhysicalIRKey& key, std::vector<std::uint8_t>& out,
                                             NativeReuse& prior, std::uint64_t& generation) {
        generation = 0;
        return LookupWithReuse(key, out, prior);
    }
    virtual void ObserveReemission(const PhysicalIRKey&, std::uint64_t, NativeReuse) {}
};

}  // namespace Dynarmic::A64
