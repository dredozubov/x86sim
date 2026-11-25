// x86Sim: simax, views that draw their own pixels (the host reads their text with OCR when they hold no elements).
//
// While the tree walk passes a view, simax_pixels_note() records it when it renders without UIKit's views: a Metal or
// OpenGL layer (CAMetalLayer, CAEAGLLayer: MTKView, GLKView, game engines such as Unity's UnityView, Flutter) or a
// SpriteKit / SceneKit view, and it covers at least 1/16 of its window's screen. The answer's `pixels` lists them:
// `frame` (screen points, as the elements'), `class` (the view's), `kind` (metal, opengl, spritekit, scenekit),
// `win`, `oid`. The host decides what counts as large and empty (docs/protocols/SIMAX.md, core/src/ocr.rs).
#include <TargetConditionals.h>
#if TARGET_OS_WATCH
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_watchos
#define __API_UNAVAILABLE_PLATFORM_watchos watchos,introduced=2.0
#endif
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL kind_of_class(Class c, NSString* name) {
	Class k = NSClassFromString(name);
	return k && [c isSubclassOfClass:k];
}

// metal / opengl / spritekit / scenekit, or nil for a view UIKit draws
NSString* simax_pixel_kind(UIView* v) {
	Class c = [v class];
	if (kind_of_class(c, @"SKView")) return @"spritekit";
	if (kind_of_class(c, @"SCNView")) return @"scenekit";
	Class lc = [v.layer class];
	if (kind_of_class(lc, @"CAMetalLayer")) return @"metal";
	if (kind_of_class(lc, @"CAEAGLLayer")) return @"opengl";
	// classes that make their layer later or host it as a sublayer
	if (kind_of_class(c, @"MTKView")) return @"metal";
	if (kind_of_class(c, @"GLKView")) return @"opengl";
	return nil;
}

void simax_pixels_note(NSMutableArray* out, UIView* v, CGRect f, int win, CGRect screen) {
	if (!out || out.count >= 16) return;
	if (f.size.width * f.size.height < screen.size.width * screen.size.height / 16) return;
	NSString* kind = simax_pixel_kind(v);
	if (!kind) return;
	CGRect on = CGRectIntersection(f, screen);
	if (CGRectIsNull(on)) return;
	[out addObject:@{
		@"frame": @[ @(round(on.origin.x * 10) / 10), @(round(on.origin.y * 10) / 10), @(round(on.size.width * 10) / 10),
			@(round(on.size.height * 10) / 10) ],
		@"class": NSStringFromClass([v class]),
		@"kind": kind,
		@"win": @(win),
		@"oid": [NSString stringWithFormat:@"%lx", (unsigned long)(uintptr_t)(__bridge void*)v],
	}];
}
