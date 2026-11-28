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
};

}  // namespace Dynarmic::A64
