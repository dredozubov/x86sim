// x86Sim (agents): network capture inside an app's process (docs/protocols/NET.md; host side
// tools/launcher/core/src/net.rs, the MCP tools net_capture / net_log / net_request / net_mock, `x86sim net`).
//
// libsimshim dlopens this only into third-party apps (and their extensions) that have capture turned on (a file
// <X86SIM_NET_DIR>/capture/<bundle id>), and calls simnet_start(). From then on a recording NSURLProtocol stands in
// front of every NSURLSessionConfiguration (protocolClasses) and NSURLProtocol's global list (the shared session,
// NSURLConnection): it loads each http(s) request itself through an inner NSURLSession made from the same
// configuration, forwards everything to the app (response, data as it arrives, redirects, authentication challenges
// including server trust, errors, cancellation) and writes one JSON line per request into
// <X86SIM_NET_DIR>/log/<bundle>-<pid>.jsonl: method, URL, both header sets, status, sizes, bodies up to the
// configured limit (text as is, other bytes base64), timings from the task's metrics, error.
//
// Mocks: <X86SIM_NET_DIR>/mocks.json (written by the host; re-read when it changes) answers matching requests with a
// status / headers / body, adds latency, or fails them (offline, timeout, DNS error, refused) without the network.
//
// Turning capture off (the host removes the capture file) takes effect at once: canInitWithRequest: answers NO and
// requests go to the system's loader as before. Background sessions (an identifier) are never touched: their tasks
// run in nsurlsessiond, out of this process. WebSocket and stream tasks are left alone too.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdatomic.h>

static NSString* g_capfile;   // the capture file that turned this process on
static NSString* g_logpath;   // where the records go
static NSString* g_mockpath;  // the mock rules
static NSString* g_bundle;
static int g_logfd = -1;
static dispatch_queue_t g_wq; // serial: record writes
static atomic_long g_seq;     // record numbers in this process (the host's id is <pid>.<n>)

// capture state, re-checked at most every 300 ms (a stat of the capture file)
static atomic_bool g_on;
static atomic_long g_limit = 256 * 1024;
static double g_checked;
static struct timespec g_cap_mtime;

static NSString* const kMarker = @"com.x86sim.net.inner";
static char kInnerConfig;

static double now_s(void) {
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return tv.tv_sec + tv.tv_usec / 1e6;
}

static void nlog(NSString* fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void nlog(NSString* fmt, ...) {
	if (!getenv("X86SIM_NET_LOG")) return;
	va_list ap;
	va_start(ap, fmt);
	NSString* s = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);
	// next to the records (an app's stderr goes nowhere): <log>.debug
	NSString* line = [NSString stringWithFormat:@"%.3f simnet: %@\n", now_s(), s];
	int fd = g_logpath ? open([g_logpath stringByAppendingString:@".debug"].fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644) : 2;
	if (fd >= 0) {
		write(fd, line.UTF8String, strlen(line.UTF8String));
		if (fd != 2) close(fd);
	}
}

static bool capture_on(void) {
	@synchronized([NSProcessInfo class]) {
		double t = now_s();
		if (t - g_checked < 0.3) return atomic_load(&g_on);
		g_checked = t;
		struct stat st;
		if (stat(g_capfile.fileSystemRepresentation, &st) != 0) {
			atomic_store(&g_on, false);
			return false;
		}
		if (st.st_mtimespec.tv_sec != g_cap_mtime.tv_sec || st.st_mtimespec.tv_nsec != g_cap_mtime.tv_nsec) {
			g_cap_mtime = st.st_mtimespec;
			NSData* d = [NSData dataWithContentsOfFile:g_capfile];
			NSDictionary* o = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
			if ([o isKindOfClass:NSDictionary.class] && [o[@"body_limit"] isKindOfClass:NSNumber.class])
				atomic_store(&g_limit, [o[@"body_limit"] longValue]);
		}
		atomic_store(&g_on, true);
		return true;
	}
}

static void write_record(NSDictionary* rec) {
	NSData* d = [NSJSONSerialization dataWithJSONObject:rec options:0 error:nil];
	if (!d) return;
	dispatch_async(g_wq, ^{
		if (g_logfd < 0) {
			g_logfd = open(g_logpath.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
			if (g_logfd < 0) return;
		}
		NSMutableData* line = [d mutableCopy];
		[line appendBytes:"\n" length:1];
		const char* p = line.bytes;
		size_t n = line.length;
		while (n > 0) {
			ssize_t k = write(g_logfd, p, n);
			if (k < 0) { if (errno == EINTR) continue; return; }
			p += k;
			n -= (size_t)k;
		}
	});
}

// ---- mocks

// A rule: {id, url (substring; with * a glob over the whole URL; "re:..." a regular expression), method,
// status, headers, body | body_b64, latency_ms, fail: offline | timeout | dns | refused | reset}
static NSArray<NSDictionary*>* g_rules;
static struct timespec g_rules_mtime;
static double g_rules_checked;

static NSArray<NSDictionary*>* mock_rules(void) {
	@synchronized([NSURLProtocol class]) {
		double t = now_s();
		if (t - g_rules_checked < 0.3) return g_rules;
		g_rules_checked = t;
		struct stat st;
		if (stat(g_mockpath.fileSystemRepresentation, &st) != 0) {
			g_rules = nil;
			memset(&g_rules_mtime, 0, sizeof g_rules_mtime);
			return nil;
		}
		if (st.st_mtimespec.tv_sec == g_rules_mtime.tv_sec && st.st_mtimespec.tv_nsec == g_rules_mtime.tv_nsec) return g_rules;
		g_rules_mtime = st.st_mtimespec;
		NSData* d = [NSData dataWithContentsOfFile:g_mockpath];
		id o = d.length ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
		if ([o isKindOfClass:NSDictionary.class]) o = o[@"rules"];
		g_rules = [o isKindOfClass:NSArray.class] ? o : nil;
		nlog(@"%lu mock rules", (unsigned long)g_rules.count);
		return g_rules;
	}
}

static bool glob_match(const char* p, const char* s) {
	// '*' any run of characters, '?' one character
	const char *star = NULL, *ss = NULL;
	while (*s) {
		if (*p == '*') { star = p++; ss = s; continue; }
		if (*p == '?' || *p == *s) { p++; s++; continue; }
		if (star) { p = star + 1; s = ++ss; continue; }
		return false;
	}
	while (*p == '*') p++;
	return !*p;
}

static bool rule_matches(NSDictionary* r, NSURLRequest* req) {
	NSString* m = r[@"method"];
	if ([m isKindOfClass:NSString.class] && m.length && ![m isEqualToString:@"*"] &&
	    [m caseInsensitiveCompare:req.HTTPMethod ?: @"GET"] != NSOrderedSame)
		return false;
	NSString* pat = r[@"url"];
	NSString* url = req.URL.absoluteString ?: @"";
	if (![pat isKindOfClass:NSString.class] || !pat.length) return true;
	if ([pat hasPrefix:@"re:"]) {
		NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:[pat substringFromIndex:3] options:0 error:nil];
		return re && [re firstMatchInString:url options:0 range:NSMakeRange(0, url.length)] != nil;
	}
	if ([pat rangeOfString:@"*"].location != NSNotFound || [pat rangeOfString:@"?"].location != NSNotFound)
		return glob_match(pat.UTF8String, url.UTF8String);
	return [url rangeOfString:pat].location != NSNotFound;
}

static NSDictionary* mock_for(NSURLRequest* req) {
	for (NSDictionary* r in mock_rules())
		if ([r isKindOfClass:NSDictionary.class] && rule_matches(r, req)) return r;
	return nil;
}

static NSError* mock_error(NSString* kind, NSURL* url) {
	NSDictionary* codes = @{
		@"offline": @[ @(NSURLErrorNotConnectedToInternet), @"The Internet connection appears to be offline." ],
		@"timeout": @[ @(NSURLErrorTimedOut), @"The request timed out." ],
		@"dns": @[ @(NSURLErrorCannotFindHost), @"A server with the specified hostname could not be found." ],
		@"refused": @[ @(NSURLErrorCannotConnectToHost), @"Could not connect to the server." ],
		@"reset": @[ @(NSURLErrorNetworkConnectionLost), @"The network connection was lost." ],
	};
	NSArray* c = codes[kind] ?: codes[@"offline"];
	NSMutableDictionary* info = [@{ NSLocalizedDescriptionKey: c[1] } mutableCopy];
	if (url) {
		info[NSURLErrorFailingURLErrorKey] = url;
		info[NSURLErrorFailingURLStringErrorKey] = url.absoluteString ?: @"";
	}
	return [NSError errorWithDomain:NSURLErrorDomain code:[c[0] integerValue] userInfo:info];
}

// ---- bodies

static NSDictionary* body_fields(NSData* d, long total, NSString* prefix) {
	long limit = atomic_load(&g_limit);
	NSMutableDictionary* o = [NSMutableDictionary dictionary];
	o[[prefix stringByAppendingString:@"_size"]] = @(total);
	if (!d.length || limit <= 0) return o;
	NSData* part = (long)d.length > limit ? [d subdataWithRange:NSMakeRange(0, (NSUInteger)limit)] : d;
	if (total > (long)part.length) o[[prefix stringByAppendingString:@"_truncated"]] = @YES;
	NSString* s = nil;
	if (!memchr(part.bytes, 0, part.length)) {
		// a cut inside a UTF-8 sequence: drop up to 3 bytes of it
		for (int cut = 0; cut < 4 && !s && (long)part.length > cut; cut++)
			s = [[NSString alloc] initWithBytes:part.bytes length:part.length - cut encoding:NSUTF8StringEncoding];
	}
	if (s) o[prefix] = s;
	else {
		o[prefix] = [part base64EncodedStringWithOptions:0];
		o[[prefix stringByAppendingString:@"_b64"]] = @YES;
	}
	return o;
}

static NSNumber* ms_between(NSDate* a, NSDate* b) {
	if (!a || !b) return nil;
	double v = [b timeIntervalSinceDate:a] * 1000.0;
	return v >= 0 ? @(round(v * 10) / 10) : nil;
}

static NSDictionary* timing_of(NSURLSessionTaskMetrics* m, double t0) {
	NSURLSessionTaskTransactionMetrics* t = nil;
	for (NSURLSessionTaskTransactionMetrics* x in m.transactionMetrics)
		if (x.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad || !t) t = x;
	NSMutableDictionary* o = [NSMutableDictionary dictionary];
	if (!t) return o;
	NSDate* start = [NSDate dateWithTimeIntervalSince1970:t0];
	o[@"dns"] = ms_between(t.domainLookupStartDate, t.domainLookupEndDate);
	o[@"connect"] = ms_between(t.connectStartDate, t.connectEndDate);
	o[@"tls"] = ms_between(t.secureConnectionStartDate, t.secureConnectionEndDate);
	o[@"send"] = ms_between(t.requestStartDate, t.requestEndDate);
	o[@"wait"] = ms_between(t.requestEndDate, t.responseStartDate);
	o[@"receive"] = ms_between(t.responseStartDate, t.responseEndDate);
	o[@"first_byte"] = ms_between(start, t.responseStartDate);
	NSMutableDictionary* x = [NSMutableDictionary dictionary];
	if (t.networkProtocolName) x[@"protocol"] = t.networkProtocolName;
	x[@"reused"] = @(t.reusedConnection);
	if (t.resourceFetchType == NSURLSessionTaskMetricsResourceFetchTypeLocalCache) x[@"cache"] = @YES;
	if (@available(iOS 13.0, *)) {
		if (t.remoteAddress) x[@"remote"] = [NSString stringWithFormat:@"%@:%@", t.remoteAddress, t.remotePort ?: @0];
		if (t.negotiatedTLSProtocolVersion) x[@"tls_version"] = [NSString stringWithFormat:@"0x%04x", t.negotiatedTLSProtocolVersion.unsignedShortValue];
	}
	return @{ @"timing": o, @"conn": x };
}

// ---- the protocol

@interface X86NetProtocol : NSURLProtocol <NSURLAuthenticationChallengeSender>
@end

// inner sessions: one per outer session (its configuration copied, so cookies, cache, additional headers, timeouts
// and TLS settings stay the app's), one delegate for all of them
@interface X86NetDemux : NSObject <NSURLSessionDataDelegate>
@property (strong) NSOperationQueue* queue;
@property (strong) NSMapTable<NSURLSessionTask*, X86NetProtocol*>* tasks;
@property (strong) NSMapTable<id, NSURLSession*>* sessions;
@property (strong) NSURLSession* fallback;
+ (instancetype)shared;
- (NSURLSession*)sessionFor:(NSURLSessionTask*)outer;
@end

@interface X86NetProtocol ()
@property (strong) NSThread* clientThread;
@property (copy) NSArray<NSString*>* modes;
@property (strong) NSURLSessionDataTask* inner;
@property (strong) NSMutableURLRequest* sent;
@property (strong) NSMutableData* body;
@property (strong) NSData* reqBody;
@property (assign) long reqSize;
@property (assign) long received;
@property (strong) NSHTTPURLResponse* response;
@property (strong) NSURLSessionTaskMetrics* metrics;
@property (strong) NSMutableDictionary* challenges; // wrapped challenge -> completion handler
@property (assign) long n;
@property (assign) double t0;
@property (assign) BOOL done;
@property (assign) BOOL stopped;
@property (copy) NSString* mockId;
@end

@implementation X86NetProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest*)r {
	NSString* s = r.URL.scheme.lowercaseString;
	if (!([s isEqualToString:@"http"] || [s isEqualToString:@"https"])) return NO;
	if ([NSURLProtocol propertyForKey:kMarker inRequest:r]) return NO;
	return capture_on();
}

+ (BOOL)canInitWithTask:(NSURLSessionTask*)task {
	// WebSocket and stream tasks keep their own connection: not this protocol's
	NSString* c = NSStringFromClass(task.class);
	if ([c rangeOfString:@"WebSocket"].location != NSNotFound || [c rangeOfString:@"StreamTask"].location != NSNotFound) return NO;
	if ([task isKindOfClass:NSClassFromString(@"NSURLSessionWebSocketTask")] || [task isKindOfClass:NSURLSessionStreamTask.class]) return NO;
	return task.currentRequest && [self canInitWithRequest:task.currentRequest];
}

+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)r {
	return r;
}

- (void)onClient:(dispatch_block_t)b {
	[self performSelector:@selector(x86_run:) onThread:self.clientThread withObject:[b copy] waitUntilDone:NO modes:self.modes];
}

- (void)x86_run:(dispatch_block_t)b {
	b();
}

static NSData* read_stream(NSInputStream* in) {
	// an upload's body reaches a protocol as a stream: read it, so it can be recorded and sent again. CFNetwork feeds
	// it from another thread (a read before it has data answered 0 and the body went empty): wait for data or its end
	NSMutableData* d = [NSMutableData data];
	[in open];
	uint8_t buf[65536];
	double deadline = now_s() + 30;
	while (now_s() < deadline) {
		NSStreamStatus st = in.streamStatus;
		if (st == NSStreamStatusAtEnd || st == NSStreamStatusError || st == NSStreamStatusClosed || st == NSStreamStatusNotOpen) break;
		if (st == NSStreamStatusOpening || !in.hasBytesAvailable) {
			usleep(500);
			continue;
		}
		NSInteger k = [in read:buf maxLength:sizeof buf];
		if (k > 0) [d appendBytes:buf length:(NSUInteger)k];
		else if (k < 0 || in.streamStatus != NSStreamStatusOpen) break;
		else if (in.streamStatus == NSStreamStatusOpen && !in.hasBytesAvailable) continue;
		else break;
	}
	nlog(@"body stream %@: %lu bytes, status %lu %@", [in class], (unsigned long)d.length, (unsigned long)in.streamStatus, in.streamError);
	[in close];
	return d;
}

// An upload task's body is not in its request: the task keeps it (_uploadData, or _uploadFile: a file URL)
static NSData* task_body(NSURLSessionTask* t) {
	if (!t) return nil;
	for (NSString* key in @[ @"_uploadData", @"_uploadFile", @"uploadData", @"uploadFile" ]) {
		id v = nil;
		SEL sel = NSSelectorFromString(key);
		if ([t respondsToSelector:sel]) {
			v = ((id (*)(id, SEL))objc_msgSend)(t, sel);
		} else {
			for (Class c = object_getClass(t); c && !v; c = class_getSuperclass(c)) {
				Ivar iv = class_getInstanceVariable(c, key.UTF8String);
				const char* enc = iv ? ivar_getTypeEncoding(iv) : NULL;
				if (iv && enc && enc[0] == '@') v = object_getIvar(t, iv);
				if (iv) break;
			}
		}
		if ([v isKindOfClass:NSData.class]) return v;
		if ([v isKindOfClass:NSURL.class] && [v isFileURL]) return [NSData dataWithContentsOfURL:v options:NSDataReadingMappedIfSafe error:nil];
	}
	return nil;
}

- (void)startLoading {
	self.clientThread = NSThread.currentThread;
	NSString* mode = NSRunLoop.currentRunLoop.currentMode;
	self.modes = mode && ![mode isEqualToString:NSDefaultRunLoopMode] ? @[ mode, NSDefaultRunLoopMode ] : @[ NSDefaultRunLoopMode ];
	self.t0 = now_s();
	self.n = atomic_fetch_add(&g_seq, 1) + 1;
	self.challenges = [NSMutableDictionary dictionary];
	NSMutableURLRequest* r = [self.request mutableCopy];
	[NSURLProtocol setProperty:@YES forKey:kMarker inRequest:r];
	nlog(@"start %@ %@ body %lu stream %@ task %@", r.HTTPMethod, r.URL, (unsigned long)r.HTTPBody.length, [r.HTTPBodyStream class], [self.task class]);
	if (r.HTTPBodyStream && !r.HTTPBody) {
		// (setting the stream to nil also drops the body: in this order)
		NSData* b = read_stream(r.HTTPBodyStream);
		r.HTTPBodyStream = nil;
		r.HTTPBody = b;
	}
	if (!r.HTTPBody.length) {
		NSData* b = task_body(self.task);
		if (!b.length) b = self.task.originalRequest.HTTPBody;
		if (b.length) r.HTTPBody = b;
	}
	self.reqBody = r.HTTPBody;
	self.reqSize = (long)r.HTTPBody.length;
	self.sent = r;
	write_record(@{ @"k": @"start", @"n": @(self.n), @"ts": @(self.t0), @"method": r.HTTPMethod ?: @"GET", @"url": r.URL.absoluteString ?: @"" });

	NSDictionary* rule = mock_for(self.request);
	if (rule) {
		self.mockId = [rule[@"id"] description] ?: @"?";
		double latency = [rule[@"latency_ms"] doubleValue] / 1000.0;
		BOOL answers = rule[@"status"] != nil || [rule[@"fail"] isKindOfClass:NSString.class];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(latency * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			[self onClient:^{
				if (self.stopped) return;
				if (answers) [self answerMock:rule];
				else [self load];  // latency only: then the network
			}];
		});
		return;
	}
	[self load];
}

- (void)load {
	NSURLSession* s = [X86NetDemux.shared sessionFor:self.task];
	NSURLSessionDataTask* t = [s dataTaskWithRequest:self.sent];
	@synchronized(X86NetDemux.shared) {
		[X86NetDemux.shared.tasks setObject:self forKey:t];
	}
	self.inner = t;
	[t resume];
}

- (void)answerMock:(NSDictionary*)rule {
	NSURL* url = self.request.URL;
	if ([rule[@"fail"] isKindOfClass:NSString.class]) {
		NSError* e = mock_error(rule[@"fail"], url);
		[self.client URLProtocol:self didFailWithError:e];
		[self finishWithError:e];
		return;
	}
	NSData* body = nil;
	if ([rule[@"body_b64"] isKindOfClass:NSString.class]) body = [[NSData alloc] initWithBase64EncodedString:rule[@"body_b64"] options:0];
	else if ([rule[@"body"] isKindOfClass:NSString.class]) body = [rule[@"body"] dataUsingEncoding:NSUTF8StringEncoding];
	else if (rule[@"body"] && ![rule[@"body"] isKindOfClass:NSNull.class]) body = [NSJSONSerialization dataWithJSONObject:rule[@"body"] options:0 error:nil];
	NSMutableDictionary* h = [NSMutableDictionary dictionary];
	if ([rule[@"headers"] isKindOfClass:NSDictionary.class])
		for (id k in rule[@"headers"]) h[[k description]] = [rule[@"headers"][k] description];
	if (body && ![h objectForKey:@"Content-Type"] && ![h objectForKey:@"content-type"]) {
		id j = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
		h[@"Content-Type"] = j ? @"application/json" : @"text/plain; charset=utf-8";
	}
	h[@"Content-Length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
	NSHTTPURLResponse* resp = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:[rule[@"status"] integerValue] ?: 200
		HTTPVersion:@"HTTP/1.1" headerFields:h];
	self.response = resp;
	[self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	if (body.length) {
		self.body = [body mutableCopy];
		self.received = (long)body.length;
		[self.client URLProtocol:self didLoadData:body];
	}
	[self.client URLProtocolDidFinishLoading:self];
	[self finishWithError:nil];
}

- (void)stopLoading {
	self.stopped = YES;
	if (self.inner && self.inner.state == NSURLSessionTaskStateRunning) [self.inner cancel];
	if (!self.done) [self finishWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{ NSLocalizedDescriptionKey: @"cancelled" }]];
}

// the record of this request (once)
- (void)finishWithError:(NSError*)e {
	@synchronized(self) {
		if (self.done) return;
		self.done = YES;
	}
	double t1 = now_s();
	NSMutableDictionary* o = [NSMutableDictionary dictionary];
	o[@"k"] = @"req";
	o[@"n"] = @(self.n);
	o[@"ts"] = @(self.t0);
	o[@"method"] = self.sent.HTTPMethod ?: @"GET";
	o[@"url"] = self.request.URL.absoluteString ?: @"";
	// what was sent: the inner task's request (the session's additional headers, cookies) over the app's
	NSMutableDictionary* rh = [NSMutableDictionary dictionaryWithDictionary:self.sent.allHTTPHeaderFields ?: @{}];
	NSURLRequest* cur = self.inner.currentRequest;
	if (cur.allHTTPHeaderFields) [rh addEntriesFromDictionary:cur.allHTTPHeaderFields];
	o[@"req_headers"] = rh;
	[o addEntriesFromDictionary:body_fields(self.reqBody, self.reqSize, @"req_body")];
	if (self.response) {
		o[@"status"] = @(self.response.statusCode);
		o[@"resp_headers"] = self.response.allHeaderFields ?: @{};
		if (self.response.MIMEType) o[@"mime"] = self.response.MIMEType;
		if (![self.response.URL isEqual:self.request.URL] && self.response.URL) o[@"final_url"] = self.response.URL.absoluteString;
	}
	[o addEntriesFromDictionary:body_fields(self.body, self.received, @"resp_body")];
	NSMutableDictionary* timing = [NSMutableDictionary dictionary];
	if (self.metrics) {
		NSDictionary* t = timing_of(self.metrics, self.t0);
		[timing addEntriesFromDictionary:t[@"timing"] ?: @{}];
		[o addEntriesFromDictionary:t[@"conn"] ?: @{}];
	}
	timing[@"total"] = @(round((t1 - self.t0) * 10000) / 10);
	o[@"timing"] = timing;
	if (self.mockId) o[@"mock"] = self.mockId;
	if (e) {
		o[@"error"] = @{ @"domain": e.domain ?: @"", @"code": @(e.code), @"text": e.localizedDescription ?: @"" };
		if (e.code == NSURLErrorCancelled && [e.domain isEqualToString:NSURLErrorDomain]) o[@"cancelled"] = @YES;
	}
	if (self.redirectTo) o[@"redirect_to"] = self.redirectTo;
	write_record(o);
}

// ---- from the inner task (the demux calls these on its queue)

- (void)innerResponse:(NSURLResponse*)resp {
	if (self.redirectTo) return;
	if ([resp isKindOfClass:NSHTTPURLResponse.class]) self.response = (NSHTTPURLResponse*)resp;
	self.body = [NSMutableData data];
	[self onClient:^{ [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed]; }];
}

- (void)innerData:(NSData*)d {
	if (self.redirectTo) return;
	self.received += (long)d.length;
	long limit = atomic_load(&g_limit);
	if ((long)self.body.length < limit) [self.body appendData:d.length > (NSUInteger)(limit - (long)self.body.length) ? [d subdataWithRange:NSMakeRange(0, (NSUInteger)(limit - (long)self.body.length))] : d];
	[self onClient:^{ [self.client URLProtocol:self didLoadData:d]; }];
}

static NSString* kRedirect = @"redirect";
- (NSString*)redirectTo {
	return objc_getAssociatedObject(self, &kRedirect);
}

- (void)innerRedirect:(NSHTTPURLResponse*)resp to:(NSURLRequest*)next {
	// as Apple's CustomHTTPProtocol sample: hand the redirect to the client (it starts a new load, a record of its
	// own) and end this one as cancelled
	self.response = resp;
	objc_setAssociatedObject(self, &kRedirect, next.URL.absoluteString, OBJC_ASSOCIATION_COPY);
	NSMutableURLRequest* m = [next mutableCopy];
	[NSURLProtocol removePropertyForKey:kMarker inRequest:m];
	[self.inner cancel];
	[self onClient:^{
		[self.client URLProtocol:self wasRedirectedToRequest:m redirectResponse:resp];
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
	}];
	[self finishWithError:nil];
}

- (void)innerChallenge:(NSURLAuthenticationChallenge*)c handler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*))h {
	NSURLAuthenticationChallenge* w = [[NSURLAuthenticationChallenge alloc] initWithAuthenticationChallenge:c sender:self];
	@synchronized(self.challenges) {
		self.challenges[[NSValue valueWithNonretainedObject:w]] = [h copy];
	}
	[self onClient:^{ [self.client URLProtocol:self didReceiveAuthenticationChallenge:w]; }];
}

- (void)innerMetrics:(NSURLSessionTaskMetrics*)m {
	self.metrics = m;
}

- (void)innerComplete:(NSError*)e {
	if (self.redirectTo) return;
	[self onClient:^{
		if (e) [self.client URLProtocol:self didFailWithError:e];
		else [self.client URLProtocolDidFinishLoading:self];
	}];
	[self finishWithError:e];
}

// ---- NSURLAuthenticationChallengeSender: the app's answer goes to the inner task

- (void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*))takeHandler:(NSURLAuthenticationChallenge*)c {
	@synchronized(self.challenges) {
		NSValue* k = [NSValue valueWithNonretainedObject:c];
		void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = self.challenges[k];
		[self.challenges removeObjectForKey:k];
		return h;
	}
}
- (void)useCredential:(NSURLCredential*)cred forAuthenticationChallenge:(NSURLAuthenticationChallenge*)c {
	void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = [self takeHandler:c];
	if (h) h(NSURLSessionAuthChallengeUseCredential, cred);
}
- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge*)c {
	void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = [self takeHandler:c];
	if (h) h(NSURLSessionAuthChallengeUseCredential, nil);
}
- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge*)c {
	void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = [self takeHandler:c];
	if (h) h(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}
- (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge*)c {
	void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = [self takeHandler:c];
	if (h) h(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}
- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge*)c {
	void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential*) = [self takeHandler:c];
	if (h) h(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
}

@end

@implementation X86NetDemux

+ (instancetype)shared {
	static X86NetDemux* d;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		d = [X86NetDemux new];
		d.queue = [NSOperationQueue new];
		d.queue.maxConcurrentOperationCount = 1;
		d.queue.name = @"com.x86sim.net";
		d.tasks = [NSMapTable strongToStrongObjectsMapTable];
		d.sessions = [NSMapTable weakToStrongObjectsMapTable];
	});
	return d;
}

static NSURLSessionConfiguration* inner_config(NSURLSessionConfiguration* outer) {
	NSURLSessionConfiguration* c = outer ? [outer copy] : [NSURLSessionConfiguration defaultSessionConfiguration];
	objc_setAssociatedObject(c, &kInnerConfig, @YES, OBJC_ASSOCIATION_RETAIN);
	NSMutableArray* p = [NSMutableArray array];
	for (Class k in c.protocolClasses)
		if (k != X86NetProtocol.class) [p addObject:k];
	c.protocolClasses = p;
	return c;
}

- (NSURLSession*)sessionFor:(NSURLSessionTask*)outer {
	NSURLSession* os = nil;
	@try {
		id v = outer ? [outer valueForKey:@"session"] : nil;
		if ([v isKindOfClass:NSURLSession.class]) os = v;
	} @catch (NSException* e) {
	}
	@synchronized(self) {
		if (!os || os.configuration.identifier) {
			if (!self.fallback) self.fallback = [NSURLSession sessionWithConfiguration:inner_config(nil) delegate:self delegateQueue:self.queue];
			return self.fallback;
		}
		NSURLSession* s = [self.sessions objectForKey:os];
		if (!s) {
			s = [NSURLSession sessionWithConfiguration:inner_config(os.configuration) delegate:self delegateQueue:self.queue];
			[self.sessions setObject:s forKey:os];
		}
		return s;
	}
}

- (X86NetProtocol*)protocolFor:(NSURLSessionTask*)t {
	@synchronized(self) {
		return [self.tasks objectForKey:t];
	}
}

- (void)URLSession:(NSURLSession*)s dataTask:(NSURLSessionDataTask*)t didReceiveResponse:(NSURLResponse*)r
	completionHandler:(void (^)(NSURLSessionResponseDisposition))h {
	[[self protocolFor:t] innerResponse:r];
	h(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession*)s dataTask:(NSURLSessionDataTask*)t didReceiveData:(NSData*)d {
	[[self protocolFor:t] innerData:d];
}

- (void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)t willPerformHTTPRedirection:(NSHTTPURLResponse*)r
	newRequest:(NSURLRequest*)next completionHandler:(void (^)(NSURLRequest*))h {
	X86NetProtocol* p = [self protocolFor:t];
	if (!p) { h(next); return; }
	[p innerRedirect:r to:next];
	h(nil);
}

- (void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)t didReceiveChallenge:(NSURLAuthenticationChallenge*)c
	completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*))h {
	X86NetProtocol* p = [self protocolFor:t];
	if (!p) { h(NSURLSessionAuthChallengePerformDefaultHandling, nil); return; }
	[p innerChallenge:c handler:h];
}

- (void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)t didFinishCollectingMetrics:(NSURLSessionTaskMetrics*)m {
	[[self protocolFor:t] innerMetrics:m];
}

- (void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)t didCompleteWithError:(NSError*)e {
	X86NetProtocol* p = [self protocolFor:t];
	@synchronized(self) {
		[self.tasks removeObjectForKey:t];
	}
	[p innerComplete:e];
}

- (void)URLSession:(NSURLSession*)s dataTask:(NSURLSessionDataTask*)t willCacheResponse:(NSCachedURLResponse*)r
	completionHandler:(void (^)(NSCachedURLResponse*))h {
	h(r);
}

@end

// ---- protocolClasses: ours first in every configuration but our own and background ones

static void hook_protocol_classes(Class cls) {
	Method m = class_getInstanceMethod(cls, @selector(protocolClasses));
	if (!m) return;
	static NSMutableSet* done;
	if (!done) done = [NSMutableSet set];
	NSValue* key = [NSValue valueWithPointer:m];
	if ([done containsObject:key]) return;
	[done addObject:key];
	NSArray* (*orig)(id, SEL) = (NSArray * (*)(id, SEL)) method_getImplementation(m);
	method_setImplementation(m, imp_implementationWithBlock(^NSArray*(NSURLSessionConfiguration* c) {
		NSArray* a = orig(c, @selector(protocolClasses));
		if (objc_getAssociatedObject(c, &kInnerConfig) || c.identifier.length || [a containsObject:X86NetProtocol.class]) return a;
		return [@[ X86NetProtocol.class ] arrayByAddingObjectsFromArray:a ?: @[]];
	}));
}

__attribute__((visibility("default"))) void simnet_start(const char* capfile, const char* logpath, const char* mockpath, const char* bundle) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		@autoreleasepool {
			g_capfile = @(capfile);
			g_logpath = @(logpath);
			g_mockpath = @(mockpath);
			g_bundle = @(bundle);
			g_wq = dispatch_queue_create("com.x86sim.net.write", DISPATCH_QUEUE_SERIAL);
			capture_on();
			hook_protocol_classes(NSURLSessionConfiguration.class);
			for (NSString* n in @[ @"__NSCFURLSessionConfiguration", @"NSURLSessionConfiguration_Mutable" ]) {
				Class c = NSClassFromString(n);
				if (c) hook_protocol_classes(c);
			}
			[NSURLProtocol registerClass:X86NetProtocol.class];
			write_record(@{ @"k": @"hello", @"ts": @(now_s()), @"pid": @(getpid()), @"bundle": g_bundle,
				@"process": NSProcessInfo.processInfo.processName ?: @"", @"body_limit": @(atomic_load(&g_limit)) });
			nlog(@"capturing %@ into %@", g_bundle, g_logpath);
		}
	});
}
