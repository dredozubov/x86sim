// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <memory>
namespace Dynarmic::A64 { class PhysicalIRCache; }

namespace a64engine {
std::shared_ptr<Dynarmic::A64::PhysicalIRCache> open_physical_store(const char* directory);
}
