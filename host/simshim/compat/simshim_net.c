// x86Sim (agents): network capture, the part in libsimshim (docs/protocols/NET.md).
//
// In a third-party app (its executable under .../Containers/Bundle/Application/) whose capture file
// <X86SIM_NET_DIR>/capture/<bundle id> exists at launch: dlopens X86SIM_NET_DYLIB (host/simnet: the recording
// NSURLProtocol for URLSession) and calls its simnet_start. Every other process: nothing.
#include <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <netdb.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

static char g_capfile[1024];     // its capture file (removed: capture off)

static bool capture_still_on(void) {
	struct stat st;
	return stat(g_capfile, &st) == 0;
}

__attribute__((constructor)) static void shim_net_init(void) {
	const char* dir = getenv("X86SIM_NET_DIR");
	if (!dir || !*dir) return;
	char exe[1024];
	uint32_t exelen = sizeof exe;
	if (_NSGetExecutablePath(exe, &exelen) != 0 || !strstr(exe, "/Containers/Bundle/Application/")) return;
	CFBundleRef b = CFBundleGetMainBundle();
	CFStringRef id = b ? CFBundleGetIdentifier(b) : NULL;
	char bundle[256];
	if (!id || !CFStringGetCString(id, bundle, sizeof bundle, kCFStringEncodingUTF8) || strchr(bundle, '/')) return;
	snprintf(g_capfile, sizeof g_capfile, "%s/capture/%s", dir, bundle);
	if (!capture_still_on()) return;
	char logdir[1024], logpath[1024], mocks[1024];
	snprintf(logdir, sizeof logdir, "%s/log", dir);
	mkdir(logdir, 0755);
	snprintf(logpath, sizeof logpath, "%s/%s-%d.jsonl", logdir, bundle, getpid());
	snprintf(mocks, sizeof mocks, "%s/mocks.json", dir);
	const char* lib = getenv("X86SIM_NET_DYLIB");
	if (!lib || !*lib) return;
	void* h = dlopen(lib, RTLD_NOW | RTLD_LOCAL);
	void (*start)(const char*, const char*, const char*, const char*) = h ? dlsym(h, "simnet_start") : NULL;
	if (!start) {
		char m[600];
		int k = snprintf(m, sizeof m, "simshim: simnet: %s\n", h ? "no simnet_start" : (dlerror() ?: "dlopen failed"));
		write(2, m, (size_t) k);
		return;
	}
	start(g_capfile, logpath, mocks, bundle);
}
