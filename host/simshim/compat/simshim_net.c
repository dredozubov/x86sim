// x86Sim (agents): network capture, the part in libsimshim (docs/protocols/NET.md).
//
// In a third-party app (its executable under .../Containers/Bundle/Application/) whose capture file
// <X86SIM_NET_DIR>/capture/<bundle id> exists at launch:
//   - dlopens X86SIM_NET_DYLIB (host/simnet: the recording NSURLProtocol for URLSession) and calls its simnet_start;
//   - records TCP connections made by any stack (dart:io, gRPC, raw sockets, also Network.framework's when it uses
//     connect): host name from the getaddrinfo answer that gave the address, port, bytes out / in (Linux TCP_INFO, read
//     with a Linux system call when the socket is closed), duration. One "conn" line per connection in
//     <X86SIM_NET_DIR>/log/<bundle>-<pid>.conn.jsonl.
// Every other process: the interposed connect / close / getaddrinfo test one flag and call through.
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

#define DYLD_INTERPOSE(_replacement, _replacee) \
	__attribute__((used)) static struct { const void* replacement; const void* replacee; } _interpose_##_replacee \
	__attribute__((section("__DATA,__interpose"))) = { (const void*) (unsigned long) &_replacement, (const void*) (unsigned long) &_replacee };

static bool g_on;                // this process is a capturing app
static char g_capfile[1024];     // its capture file (removed: capture off)
static char g_connlog[1024];
static int g_connfd = -1;
static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;
static unsigned long g_nconn;

// a Linux system call (Darling processes are Linux processes): under libarm64jit "svc #0xfffe" is one, x8 = the
// x86_64 system call number (as in simfb / openurl)
static long linux_syscall5(long n, long a, long b, long c, long d, long e) {
	register long x0 __asm__("x0") = a, x1 __asm__("x1") = b, x2 __asm__("x2") = c, x3 __asm__("x3") = d, x4 __asm__("x4") = e;
	register long x8 __asm__("x8") = n;
	__asm__ volatile("svc #0xfffe" : "+r"(x0) : "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x8) : "memory");
	return x0;
}

static double now_s(void) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec + tv.tv_usec / 1e6;
}

// ---- names from DNS answers: address -> host (the last 128)
struct name { char addr[48]; char host[200]; };
static struct name g_names[128];
static unsigned g_nnames;

static void addr_text(const struct sockaddr* sa, char* out, size_t n, int* port) {
	*out = 0;
	if (port) *port = 0;
	if (sa->sa_family == AF_INET) {
		const struct sockaddr_in* s = (const void*) sa;
		inet_ntop(AF_INET, &s->sin_addr, out, (socklen_t) n);
		if (port) *port = ntohs(s->sin_port);
	} else if (sa->sa_family == AF_INET6) {
		const struct sockaddr_in6* s = (const void*) sa;
		inet_ntop(AF_INET6, &s->sin6_addr, out, (socklen_t) n);
		if (port) *port = ntohs(s->sin6_port);
	}
}

static int shim_getaddrinfo(const char* host, const char* serv, const struct addrinfo* hints, struct addrinfo** res) {
	int r = getaddrinfo(host, serv, hints, res);
	if (!g_on || r != 0 || !host || !res) return r;
	pthread_mutex_lock(&g_mu);
	for (struct addrinfo* a = *res; a; a = a->ai_next) {
		if (!a->ai_addr) continue;
		char t[48];
		addr_text(a->ai_addr, t, sizeof t, NULL);
		if (!*t || !strcmp(t, host)) continue;
		struct name* e = &g_names[g_nnames++ % 128];
		strlcpy(e->addr, t, sizeof e->addr);
		strlcpy(e->host, host, sizeof e->host);
	}
	pthread_mutex_unlock(&g_mu);
	return r;
}
DYLD_INTERPOSE(shim_getaddrinfo, getaddrinfo)

// ---- connections: fd -> where and since when
#define MAXFD 4096
struct conn { double t0; int port; char addr[48]; char host[200]; };
static struct conn* g_conns[MAXFD];

static bool capture_still_on(void) {
	struct stat st;
	return stat(g_capfile, &st) == 0;
}

static void json_str(char* out, size_t n, const char* s) {
	size_t o = 0;
	for (; *s && o + 7 < n; s++) {
		unsigned char c = (unsigned char) *s;
		if (c == '"' || c == '\\') { out[o++] = '\\'; out[o++] = (char) c; }
		else if (c < 0x20) o += (size_t) snprintf(out + o, n - o, "\\u%04x", c);
		else out[o++] = (char) c;
	}
	out[o] = 0;
}

static void conn_done(int fd, struct conn* c, const char* how) {
	// Linux TCP_INFO (struct tcp_info: bytes_acked at 120, bytes_received at 128, bytes_sent at 200)
	unsigned char ti[232];
	memset(ti, 0, sizeof ti);
	unsigned int len = sizeof ti;
	long r = linux_syscall5(55 /* getsockopt */, fd, 6 /* IPPROTO_TCP */, 11 /* TCP_INFO */, (long) ti, (long) &len);
	uint64_t out = 0, in = 0, sent = 0;
	if (r == 0) {
		memcpy(&out, ti + 120, 8);
		memcpy(&in, ti + 128, 8);
		if (len >= 208) memcpy(&sent, ti + 200, 8);
		if (sent > out) out = sent;
	}
	char host[420], line[1024];
	json_str(host, sizeof host, c->host);
	double t1 = now_s();
	pthread_mutex_lock(&g_mu);
	unsigned long n = ++g_nconn;
	int k = snprintf(line, sizeof line,
		"{\"k\":\"conn\",\"n\":%lu,\"ts\":%.6f,\"proto\":\"tcp\",\"host\":\"%s\",\"addr\":\"%s\",\"port\":%d,"
		"\"bytes_out\":%llu,\"bytes_in\":%llu,\"bytes_known\":%s,\"duration_ms\":%.1f,\"end\":\"%s\"}\n",
		n, c->t0, host, c->addr, c->port, (unsigned long long) out, (unsigned long long) in, r == 0 ? "true" : "false",
		(t1 - c->t0) * 1000.0, how);
	if (g_connfd < 0) g_connfd = open(g_connlog, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
	if (g_connfd >= 0 && k > 0) write(g_connfd, line, (size_t) k);
	pthread_mutex_unlock(&g_mu);
}

static int shim_connect(int fd, const struct sockaddr* sa, socklen_t len) {
	int r = connect(fd, sa, len);
	if (!g_on || !sa || fd < 0 || fd >= MAXFD || (sa->sa_family != AF_INET && sa->sa_family != AF_INET6)) return r;
	int e = errno;
	if (r != 0 && e != EINPROGRESS) return r;
	int type = 0;
	socklen_t tl = sizeof type;
	if (getsockopt(fd, SOL_SOCKET, SO_TYPE, &type, &tl) != 0 || type != SOCK_STREAM || !capture_still_on()) {
		errno = e;
		return r;
	}
	struct conn* c = calloc(1, sizeof *c);
	if (c) {
		c->t0 = now_s();
		addr_text(sa, c->addr, sizeof c->addr, &c->port);
		pthread_mutex_lock(&g_mu);
		for (unsigned i = 0; i < 128 && i < g_nnames; i++) {
			struct name* nm = &g_names[(g_nnames - 1 - i) % 128];
			if (!strcmp(nm->addr, c->addr)) { strlcpy(c->host, nm->host, sizeof c->host); break; }
		}
		struct conn* old = g_conns[fd];
		g_conns[fd] = c;
		pthread_mutex_unlock(&g_mu);
		free(old);
	}
	errno = e;
	return r;
}
DYLD_INTERPOSE(shim_connect, connect)

static int shim_close(int fd) {
	if (g_on && fd >= 0 && fd < MAXFD && g_conns[fd]) {
		pthread_mutex_lock(&g_mu);
		struct conn* c = g_conns[fd];
		g_conns[fd] = NULL;
		pthread_mutex_unlock(&g_mu);
		if (c) {
			conn_done(fd, c, "close");
			free(c);
		}
	}
	return close(fd);
}
DYLD_INTERPOSE(shim_close, close)

static void flush_conns(void) {
	for (int fd = 0; fd < MAXFD; fd++) {
		struct conn* c = g_conns[fd];
		if (!c) continue;
		g_conns[fd] = NULL;
		conn_done(fd, c, "exit");
		free(c);
	}
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
	snprintf(g_connlog, sizeof g_connlog, "%s/%s-%d.conn.jsonl", logdir, bundle, getpid());
	snprintf(mocks, sizeof mocks, "%s/mocks.json", dir);
	g_on = true;
	atexit(flush_conns);
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
