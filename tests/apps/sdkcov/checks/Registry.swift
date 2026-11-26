// sdkcov: every functional check, in run order. Each group lives in its own file (checks/<Group>.swift) and guards
// platform-specific frameworks with #if canImport / #if os, so one source tree builds for iOS, tvOS, watchOS and visionOS.
enum Registry {
    static var all: [Check] { Array([core, libraries, graphics, media, data, services, ui, ml, platform, more_ios, more_tvos, more_watchos, more_xros, inputs, more_ipados, more2_system, more2_net, more2_graphics, more2_ui, rename_probe, p4, p8, p1, p7, p2, p5, p6, p3, p9, p10, p11, p12, p13, p14, p14_models, p15, p16_touch, p16, p17, p18, p19, p20, p21, p23, p22, p24, p25, p26, p27ui, p27swiftui, p27media, p27data, p27svc].joined()) }
}
