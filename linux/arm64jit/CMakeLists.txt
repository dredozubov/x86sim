# Stage 1 of the arm64 plan: libarm64jit.so, the ELF side of arm64 iOS-simulator processes inside Darling (dynarmic,
# the svc boundary, stub dylibs for the host libraries, dyld_sim setup). Loaded by host/arm64host through elfcalls.
cmake_minimum_required(VERSION 3.20)
project(arm64jit C CXX ASM)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(DYNARMIC_SRC ${CMAKE_CURRENT_SOURCE_DIR}/../../external/dynarmic CACHE PATH "dynarmic source")
set(DYNARMIC_TESTS OFF CACHE BOOL "" FORCE)
set(DYNARMIC_FRONTENDS A64 CACHE STRING "" FORCE)
set(DYNARMIC_USE_BUNDLED_EXTERNALS ON CACHE BOOL "" FORCE)
set(DYNARMIC_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
# ThinLTO across libarm64jit and dynarmic: dynarmic's translator makes millions of calls to tiny out-of-line IR helpers
# (Value::GetType/IsImmediate, GetNumArgsOf, RegAlloc). Measured 2026-11-25 on an iPhone 18 Pro boot without the
# translation cache: 22-31% less translation time per block in SpringBoard and backboardd. Emitted code is unchanged,
# so AOT images stay valid. -DX86SIM_JIT_LTO=OFF builds without it.
option(X86SIM_JIT_LTO "ThinLTO for libarm64jit + dynarmic" ON)
find_program(X86SIM_LLD ld.lld)
if(X86SIM_JIT_LTO AND CMAKE_CXX_COMPILER_ID MATCHES "Clang" AND X86SIM_LLD)
	add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-flto=thin>)
	add_link_options(-flto=thin -fuse-ld=lld)
endif()
add_subdirectory(${DYNARMIC_SRC} dynarmic EXCLUDE_FROM_ALL)
add_executable(a64hugecopy a64hugecopy.c)
add_library(arm64jit SHARED host.cpp jit.cpp boundary.cpp handlers.cpp malloc.cpp objc.cpp gheap.cpp signals.cpp fp16.cpp stubdylib.cpp jitcache.cpp dyldsim.cpp guestlibc.cpp swiftconf.cpp swiftscan.cpp astc.cpp lzfse.cpp gdbstub.cpp prof.cpp callconv.S)
target_compile_options(arm64jit PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-O2 -mcx16 -Wall -fvisibility=hidden>)
target_link_options(arm64jit PRIVATE -static-libstdc++ -static-libgcc -Wl,--no-undefined)
target_link_libraries(arm64jit PRIVATE dynarmic pthread)
# Speed 31: ARM's astc-encoder (third_party/astcenc, Apache-2.0) for the native libate ASTC decode (astc.cpp)
file(GLOB ASTCENC_SRC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/astcenc/astcenc_*.cpp)
add_library(astcenc_x86sim STATIC ${ASTCENC_SRC})
target_compile_definitions(astcenc_x86sim PRIVATE ASTCENC_SSE=41 ASTCENC_AVX=0 ASTCENC_POPCNT=1 ASTCENC_F16C=0 ASTCENC_NEON=0 ASTCENC_SVE=0)
target_compile_options(astcenc_x86sim PRIVATE -O2 -msse4.1 -mpopcnt -fvisibility=hidden -w)
target_link_libraries(arm64jit PRIVATE astcenc_x86sim)
# Speed 32: Apple's reference LZFSE decoder (third_party/lzfse, BSD-3; from Darling's src/external/lzfse) for lzfse.cpp
add_library(lzfse_x86sim STATIC third_party/lzfse/lzfse_decode.c third_party/lzfse/lzfse_decode_base.c
            third_party/lzfse/lzfse_fse.c third_party/lzfse/lzvn_decode_base.c)
target_compile_options(lzfse_x86sim PRIVATE -O2 -fvisibility=hidden -fPIC -w)
target_link_libraries(arm64jit PRIVATE lzfse_x86sim)
