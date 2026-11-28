// x86Sim: dyld interposing for libsimswt (simswt.swift): Testing's Event.ConsoleOutputRecorder.record(_:in:) -> ours.
// Both have Swift's calling convention and the same signature; dyld does not rebind the interposing image itself.
extern char x86sim_swt_record;
extern char swt_record __asm__("_$s7Testing5EventV21ConsoleOutputRecorderV6record_2inSbAC_AC7ContextVtF") __attribute__((weak_import));

__attribute__((used)) static const struct { const void *replacement, *replacee; } interposers[]
	__attribute__((section("__DATA,__interpose"))) = { { &x86sim_swt_record, &swt_record } };
