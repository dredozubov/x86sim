# Rules for agents working in this repository

## Everything builds on Linux

- x86Sim is built on Linux. Every binary, library, test app and resource must build here with the Linux toolchain
  (build/linux-env.sh: clang, ld64.lld, swiftc and the SDKs in sdks/). Nothing in the product, the release or the
  setup may depend on copying files or build output from a Mac.
- The Mac ($X86SIM_MAC) is for comparison testing and validation: running the same app, check or input on Apple's
  simulator to see what Apple does (tests/apps/sdkcov/ref-mac.sh), and validating x86Sim's results against it. It
  is not a build machine and not a source of files for the product. If something really cannot be built here, say
  so in the change, explain why, and find the Linux path before adding a Mac dependency.

## Stopping processes

- Kill by PID, never by pattern. Keep the PID of what you start (`$!`, a pidfile, the `pid` a tool returns) and
  `kill <pid>`. Never `pkill -f`/`killall`: a pattern also matches your own shell's command line (which contains the
  pattern) and kills it, and it can hit the user's processes (another phone, a running build).
- To stop a phone, use its own stop (`x86sim` / the MCP `sim_stop phone=<name>`), not a signal to Darling processes.
