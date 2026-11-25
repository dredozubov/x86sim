// x86Sim: simax's readers for content UIKit's accessibility does not describe (game engines, SpriteKit, SceneKit),
// hooked from simax.m (protocol: docs/protocols/SIMAX.md, "Engines").
//
//   simax_engines_screen_reader()  once, at a process's first tree: Flutter builds its accessibility tree only while
//                                  a screen reader runs. In Flutter's image
//                                  UIAccessibilityIsVoiceOverRunning answers yes (their bound pointers to it are
//                                  rebound), and the "VoiceOver status changed" notification makes them look again.
//                                  Nothing else in the process sees VoiceOver on.
//   simax_engine_view(v)           whether v is a view whose content an engine reader describes: SKView, SCNView
//                                  (1: always, less the nodes their own accessibility lists)
//   simax_engine_elements(v)       that content: SpriteKit / SceneKit named nodes (role node)
//
// Frames are in the view's own points; simax.m turns them into screen points as it does for any element.
#include <TargetConditionals.h>
#if TARGET_OS_WATCH
// (as simax.m: watchOS's headers mark UIKit unavailable, UIKitCore runs every watch app)
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_watchos
#define __API_UNAVAILABLE_PLATFORM_watchos watchos,introduced=2.0
#endif
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>

void simax_log(const char* fmt, ...);

// ---------------------------------------------------------------------------------------------------------------------
// The screen-reader switch

static BOOL vo_yes(void) { return YES; }

// Rebinds every pointer to `from` in an image's symbol pointer sections (__got, __auth_got, __la_symbol_ptr: what its
// calls to an imported function load) to `to`. Answers how many it changed. The image's own code is not touched.
static int rebind_image(const struct mach_header_64* mh, intptr_t slide, void* from, void* to) {
	int n = 0;
	const uint8_t* p = (const uint8_t*)(mh + 1);
	long page = sysconf(_SC_PAGESIZE);
	for (uint32_t i = 0; i < mh->ncmds; i++) {
		const struct load_command* lc = (const void*)p;
		if (lc->cmd == LC_SEGMENT_64) {
			const struct segment_command_64* sg = (const void*)lc;
			const struct section_64* s = (const void*)(sg + 1);
			for (uint32_t j = 0; j < sg->nsects; j++, s++) {
				uint32_t type = s->flags & SECTION_TYPE;
				if (type != S_NON_LAZY_SYMBOL_POINTERS && type != S_LAZY_SYMBOL_POINTERS && strncmp(s->sectname, "__got", 16) &&
				    strncmp(s->sectname, "__auth_got", 16) && strncmp(s->sectname, "__la_symbol_ptr", 16))
					continue;
				void** v = (void**)(s->addr + slide);
				size_t count = s->size / sizeof(void*);
				for (size_t k = 0; k < count; k++) {
					if (v[k] != from) continue;
					uintptr_t a = (uintptr_t)&v[k] & ~(uintptr_t)(page - 1);
					// __DATA_CONST is read-only once dyld bound it: writable for the store, read-only again after
					BOOL ro = mprotect((void*)a, page, PROT_READ | PROT_WRITE) == 0;
					v[k] = to;
					if (ro && !strncmp(sg->segname, "__DATA_CONST", 16)) mprotect((void*)a, page, PROT_READ);
					n++;
				}
			}
		}
		p += lc->cmdsize;
	}
	return n;
}

void simax_engines_screen_reader(void) {
	static BOOL done;
	if (done) return;
	done = YES;
	void* vo = dlsym(RTLD_DEFAULT, "UIAccessibilityIsVoiceOverRunning");
	if (!vo) return;
	NSMutableArray* which = [NSMutableArray array];
	int total = 0;
	for (uint32_t i = 0, n = _dyld_image_count(); i < n; i++) {
		const struct mach_header* mh = _dyld_get_image_header(i);
		const char* path = _dyld_get_image_name(i);
		NSString* eng = nil;
		if (path && strstr(path, "/Flutter.framework/Flutter")) eng = @"flutter";
		if (!eng || mh->magic != MH_MAGIC_64) continue;
		int k = rebind_image((const struct mach_header_64*)mh, _dyld_get_image_vmaddr_slide(i), vo, (void*)vo_yes);
		total += k;
		[which addObject:[NSString stringWithFormat:@"%@:%d", eng, k]];
	}
	if (!which.count) return;
	simax_log("engines: screen reader on for %s", [which componentsJoinedByString:@" "].UTF8String);
	if (!total) return;
	// what UIKit posts when VoiceOver turns on: the engines re-read the setting and build their trees
	[NSNotificationCenter.defaultCenter postNotificationName:UIAccessibilityVoiceOverStatusDidChangeNotification object:nil];
	[NSNotificationCenter.defaultCenter postNotificationName:@"UIAccessibilityVoiceOverStatusChanged" object:nil];
}

// ---------------------------------------------------------------------------------------------------------------------
// SpriteKit and SceneKit: named nodes. Called by name (no link to either framework: a process without them pays nothing)

typedef struct { float x, y, z; } V3;   // SCNVector3 on iOS / tvOS / watchOS / visionOS (floats)

static NSString* sname(id o) {
	NSString* s = nil;
	@try { s = ((id(*)(id, SEL))objc_msgSend)(o, @selector(name)); } @catch (id ex) { s = nil; }
	return [s isKindOfClass:[NSString class]] && s.length ? s : nil;
}

static NSArray* kids(id o, SEL sel) {
	NSArray* a = nil;
	@try { a = ((id(*)(id, SEL))objc_msgSend)(o, sel); } @catch (id ex) { a = nil; }
	return [a isKindOfClass:[NSArray class]] ? a : @[];
}

static NSString* rkey(NSString* prefix, NSString* name, NSMutableDictionary* nth) {
	int n = [nth[name] intValue];
	nth[name] = @(n + 1);
	return [NSString stringWithFormat:@"%@:%@#%d", prefix, name, n];
}

static NSDictionary* node_el(id node, NSString* name, CGRect r, NSString* key) {
	return @{ @"role": @"node", @"label": name, @"key": key, @"rect": [NSValue valueWithCGRect:r],
		@"oid": [NSString stringWithFormat:@"%lx", (unsigned long)(uintptr_t)(__bridge void*)node], @"class": NSStringFromClass([node class]) };
}

// SpriteKit: the scene's tree, depth first; hidden / transparent nodes and their subtrees skipped, frames from
// calculateAccumulatedFrame (the parent's coordinates) through the scene to the view
static void sk_walk(UIView* view, id scene, id node, int depth, NSMutableDictionary* nth, NSMutableArray* out) {
	if (depth > 64 || out.count > 500) return;
	@try {
		if (((BOOL(*)(id, SEL))objc_msgSend)(node, @selector(isHidden))) return;
		if (((CGFloat(*)(id, SEL))objc_msgSend)(node, @selector(alpha)) < 0.01) return;
	} @catch (id ex) {
		return;
	}
	NSString* name = node == scene ? nil : sname(node);
	if (name) {
		@try {
			CGRect f = ((CGRect(*)(id, SEL))objc_msgSend)(node, @selector(calculateAccumulatedFrame));
			id parent = ((id(*)(id, SEL))objc_msgSend)(node, @selector(parent));
			if (!CGRectIsNull(f) && f.size.width > 0 && f.size.height > 0 && parent) {
				CGPoint c[4] = { f.origin, { CGRectGetMaxX(f), f.origin.y }, { f.origin.x, CGRectGetMaxY(f) }, { CGRectGetMaxX(f), CGRectGetMaxY(f) } };
				CGFloat x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
				for (int i = 0; i < 4; i++) {
					CGPoint s = parent == scene ? c[i] : ((CGPoint(*)(id, SEL, CGPoint, id))objc_msgSend)(parent, @selector(convertPoint:toNode:), c[i], scene);
					CGPoint v = ((CGPoint(*)(id, SEL, CGPoint))objc_msgSend)(scene, @selector(convertPointToView:), s);
					x0 = MIN(x0, v.x); y0 = MIN(y0, v.y); x1 = MAX(x1, v.x); y1 = MAX(y1, v.y);
				}
				CGRect r = CGRectIntersection(CGRectMake(x0, y0, x1 - x0, y1 - y0), view.bounds);
				NSString* key = rkey(@"sk", name, nth);   // counted on screen or not: the n-th stays the n-th
				if (!CGRectIsNull(r) && r.size.width > 0.5 && r.size.height > 0.5) [out addObject:node_el(node, name, r, key)];
			}
		} @catch (id ex) {
		}
	}
	for (id k in kids(node, @selector(children))) sk_walk(view, scene, k, depth + 1, nth, out);
}

static NSArray* sk_elements(UIView* v) {
	id scene = nil;
	@try { scene = ((id(*)(id, SEL))objc_msgSend)(v, @selector(scene)); } @catch (id ex) { scene = nil; }
	if (!scene) return @[];
	NSMutableArray* out = [NSMutableArray array];
	sk_walk(v, scene, scene, 0, [NSMutableDictionary dictionary], out);
	return out;
}

// SceneKit: the root node's tree (presentation nodes: where animations put them now); each named node's bounding box
// (its subtree's) projected to the view. Nodes behind the camera, and nodes a hit test at their center reaches only
// behind something else (covered), are left out.
static BOOL descends(id n, id anc) {
	for (int i = 0; n && i < 64; i++) {
		if (n == anc) return YES;
		@try { n = ((id(*)(id, SEL))objc_msgSend)(n, @selector(parentNode)); } @catch (id ex) { return NO; }
	}
	return NO;
}

static void scn_walk(UIView* view, id node, int depth, NSMutableDictionary* nth, NSMutableArray* out, NSDictionary* hopts) {
	if (depth > 64 || out.count > 500) return;
	@try {
		if (((BOOL(*)(id, SEL))objc_msgSend)(node, @selector(isHidden))) return;
		if (((CGFloat(*)(id, SEL))objc_msgSend)(node, @selector(opacity)) < 0.01) return;
	} @catch (id ex) {
		return;
	}
	NSString* name = sname(node);
	if (name) {
		NSString* key = rkey(@"scn", name, nth);
		@try {
			id pn = ((id(*)(id, SEL))objc_msgSend)(node, @selector(presentationNode)) ?: node;
			V3 mn = { 0 }, mx = { 0 };
			BOOL has = ((BOOL(*)(id, SEL, V3*, V3*))objc_msgSend)(pn, @selector(getBoundingBoxMin:max:), &mn, &mx);
			if (has && (mx.x > mn.x || mx.y > mn.y || mx.z > mn.z)) {
				CGFloat x0 = INFINITY, y0 = INFINITY, x1 = -INFINITY, y1 = -INFINITY;
				int front = 0;
				for (int i = 0; i < 8; i++) {
					V3 c = { i & 1 ? mx.x : mn.x, i & 2 ? mx.y : mn.y, i & 4 ? mx.z : mn.z };
					V3 w = ((V3(*)(id, SEL, V3, id))objc_msgSend)(pn, @selector(convertPosition:toNode:), c, nil);
					V3 s = ((V3(*)(id, SEL, V3))objc_msgSend)(view, @selector(projectPoint:), w);
					if (s.z < 0 || s.z > 1) continue;   // behind the camera (or past its far plane)
					front++;
					x0 = MIN(x0, s.x); y0 = MIN(y0, s.y); x1 = MAX(x1, s.x); y1 = MAX(y1, s.y);
				}
				CGRect r = front ? CGRectIntersection(CGRectMake(x0, y0, x1 - x0, y1 - y0), view.bounds) : CGRectNull;
				if (!CGRectIsNull(r) && r.size.width > 0.5 && r.size.height > 0.5) {
					// covered: the ray through its center meets something else first and it only later
					CGPoint mid = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
					NSArray* hits = ((id(*)(id, SEL, CGPoint, id))objc_msgSend)(view, @selector(hitTest:options:), mid, hopts);
					BOOL covered = NO;
					if (hits.count && !descends([hits[0] valueForKey:@"node"], node) && !descends([hits[0] valueForKey:@"node"], pn))
						for (id h in hits)
							if (descends([h valueForKey:@"node"], node) || descends([h valueForKey:@"node"], pn)) { covered = YES; break; }
					if (!covered) [out addObject:node_el(node, name, r, key)];
				}
			}
		} @catch (id ex) {
		}
	}
	for (id k in kids(node, @selector(childNodes))) scn_walk(view, k, depth + 1, nth, out, hopts);
}

static NSArray* scn_elements(UIView* v) {
	id scene = nil, root = nil;
	@try {
		scene = ((id(*)(id, SEL))objc_msgSend)(v, @selector(scene));
		root = scene ? ((id(*)(id, SEL))objc_msgSend)(scene, @selector(rootNode)) : nil;
	} @catch (id ex) {
		root = nil;
	}
	if (!root) return @[];
	// every node along the ray (SCNHitTestSearchModeAll = 1), hidden ones not
	NSString* __unsafe_unretained* mode = (NSString* __unsafe_unretained*)dlsym(RTLD_DEFAULT, "SCNHitTestOptionSearchMode");
	NSString* __unsafe_unretained* ignh = (NSString* __unsafe_unretained*)dlsym(RTLD_DEFAULT, "SCNHitTestOptionIgnoreHiddenNodes");
	NSMutableDictionary* hopts = [NSMutableDictionary dictionary];
	if (mode && *mode) hopts[*mode] = @1;
	if (ignh && *ignh) hopts[*ignh] = @YES;
	NSMutableArray* out = [NSMutableArray array];
	scn_walk(v, root, 0, [NSMutableDictionary dictionary], out, hopts);
	return out;
}

// ---------------------------------------------------------------------------------------------------------------------

static Class cls(const char* n) {
	return objc_getClass(n);
}

// 1: SpriteKit / SceneKit (their named nodes, besides what their own accessibility lists), 0: neither. Looked up each
// time: a framework, and with it its class, can load later.
int simax_engine_view(UIView* v) {
	Class sk = cls("SKView"), scn = cls("SCNView");
	return (sk && [v isKindOfClass:sk]) || (scn && [v isKindOfClass:scn]) ? 1 : 0;
}

NSArray* simax_engine_elements(UIView* v) {
	Class sk = cls("SKView"), scn = cls("SCNView");
	if (sk && [v isKindOfClass:sk]) return sk_elements(v);
	if (scn && [v isKindOfClass:scn]) return scn_elements(v);
	return @[];
}
