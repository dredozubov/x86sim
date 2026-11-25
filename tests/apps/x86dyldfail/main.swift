// x86dyldfail: an app dyld refuses to start: it imports a symbol no library exports (linked with
// `-undefined dynamic_lookup`, swiftc.flags), so dyld halts at launch with "Symbol not found" (abort_with_payload,
// namespace DYLD) before any of the app's code or libsimshim runs. tests/ax/devices_e2e.py (abort) checks that
// app_launch fails with that reason and that app_logs / app_state show it.
@_silgen_name("x86sim_no_such_symbol")
func noSuchSymbol() -> Int32

print("x86dyldfail: dyld let me start (it should not have)", noSuchSymbol())
