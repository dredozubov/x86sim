// x86Sim simulator shim, part of libsimshim: why a process aborted. abort_with_payload / abort_with_reason (what
// libobjc's fatal errors, libdispatch's "BUG IN CLIENT", RunningBoard / FrontBoard terminations and an app's own calls
// end in) are recorded before they run, one line per call, into the device's log folder:
//   <data>/var/log/x86sim-exit/<executable>.<pid>.log   "<UTC time> <function> namespace <n> code <0x..>: <reason>"
// The host shows the newest one for an app in app_logs, app_state (last exit) and app_launch's error
// (tools/launcher/core/src/appstate.rs). dyld's own halts (library not loaded, missing symbol, wrong platform) happen
// before this library is loaded: the translator's per-process log records those (linux/arm64jit handlers.cpp
// h_abort_with), and the host reads both.
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include "diagpath.h"

#define DYLD_INTERPOSE(_replacement, _replacee) \
	__attribute__((used)) static struct { const void* replacement; const void* replacee; } _interpose_##_replacee \
	__attribute__((section("__DATA,__interpose"))) = { (const void*) (unsigned long) &_replacement, (const void*) (unsigned long) &_replacee };

extern void abort_with_payload(uint32_t ns, uint64_t code, void* payload, uint32_t size, const char* reason, uint64_t flags) __attribute__((noreturn));
extern void abort_with_reason(uint32_t ns, uint64_t code, const char* reason, uint64_t flags) __attribute__((noreturn));

static void record(const char* fn, uint32_t ns, uint64_t code, const char* reason)
{
	char dir[1200], path[1400], ts[40] = "";
	snprintf(dir, sizeof(dir), "%s/var/log/x86sim-exit", diag_data_dir());
	mkdir(dir, 0755);
	const char* exe = getprogname();
	snprintf(path, sizeof(path), "%s/%s.%d.log", dir, exe && *exe ? exe : "process", getpid());
	int fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
	if (fd < 0) return;
	time_t t = time(NULL);
	struct tm tm;
	if (gmtime_r(&t, &tm)) strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", &tm);
	// one line: newlines in the reason (dyld's multi-line ones) become " | "
	char r[1500];
	size_t n = 0;
	for (const char* p = reason ? reason : "(no reason)"; *p && n + 4 < sizeof(r); p++) {
		if (*p == '\n') { if (p[1]) { r[n++] = ' '; r[n++] = '|'; r[n++] = ' '; } }
		else r[n++] = *p;
	}
	r[n] = 0;
	dprintf(fd, "%s %s namespace %u code %#llx: %s\n", ts, fn, ns, (unsigned long long)code, r);
	close(fd);
}

static void shim_abort_with_payload(uint32_t ns, uint64_t code, void* payload, uint32_t size, const char* reason, uint64_t flags)
{
	record("abort_with_payload", ns, code, reason);
	abort_with_payload(ns, code, payload, size, reason, flags);
}
DYLD_INTERPOSE(shim_abort_with_payload, abort_with_payload)

static void shim_abort_with_reason(uint32_t ns, uint64_t code, const char* reason, uint64_t flags)
{
	record("abort_with_reason", ns, code, reason);
	abort_with_reason(ns, code, reason, flags);
}
DYLD_INTERPOSE(shim_abort_with_reason, abort_with_reason)
