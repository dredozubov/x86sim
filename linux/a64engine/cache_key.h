// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <cstdint>
#include <span>
#include <string>

namespace a64engine {
// The image identifies immutable inputs. The profile identifies code generation.
// Keep x86sim's deployed <dyld-uuid>-<build> filename format.
inline std::string cache_key(std::span<const std::uint8_t> image, std::uint64_t profile) {
    constexpr char digits[] = "0123456789abcdef";
    std::string key;
    key.reserve(2 * image.size() + 17);
    for (auto byte : image) {
        key.push_back(digits[byte >> 4]);
        key.push_back(digits[byte & 15]);
    }
    key.push_back('-');
    for (int shift = 60; shift >= 0; shift -= 4) key.push_back(digits[(profile >> shift) & 15]);
    return key;
}
} // namespace a64engine
