// sdkcov's Core Image kernels (stitchable, Metal): compiled per platform with Apple's Metal toolchain (on Linux) into
// res/sdkcovCI-<platform>.metallib by res/sdkcovCI.sh; func:CoreImage.cikernel-metal-library (checks/P22_Gaps.swift)
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" {
namespace coreimage {
    // swap red and blue, keep green and alpha
    [[stitchable]] float4 sdkcovSwapRB(sample_t s) { return float4(s.b, s.g, s.r, s.a); }
    // a warp: sample from 10 px to the right
    [[stitchable]] float2 sdkcovShift(destination d) { return d.coord() + float2(10, 0); }
}
}
