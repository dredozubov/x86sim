// x86Sim: simax's action requests for agents (agent tools round 2; host side tools/launcher/core/src/axact.rs, protocol
// docs/protocols/SIMAX.md). Kept apart from simax.m, which calls simax_actions_handle() from its request dispatch.
//
//   focus                  the first responder: oid, class, kind (textfield / securefield / searchfield / textview / web /
//                          keyinput / other), its frame on the screen, value, placeholder, and the oids of the views it
//                          is inside (the host matches a tapped element against them)
#include <TargetConditionals.h>
#if TARGET_OS_WATCH
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_watchos
#define __API_UNAVAILABLE_PLATFORM_watchos watchos,introduced=2.0
#endif
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// from simax.m
id simax_find_oid(NSString* oid);
UIResponder* simax_first_responder(void);
NSString* simax_hex(id o);

static BOOL isa_(id o, NSString* cls) {
	Class c = NSClassFromString(cls);
	return c && [o isKindOfClass:c];
}

static NSString* s_(id v) {
	if (!v) return nil;
	if ([v isKindOfClass:[NSString class]]) return [(NSString*)v length] ? v : nil;
	if ([v isKindOfClass:[NSAttributedString class]]) { NSString* s = [v string]; return s.length ? s : nil; }
	if ([v respondsToSelector:@selector(stringValue)]) return [v stringValue];
	return nil;
}

static id kv(id o, NSString* k) {
	@try { return [o valueForKey:k]; } @catch (id ex) { return nil; }
}

static NSArray* rect_a(CGRect f) {
	return @[ @(round(f.origin.x * 10) / 10), @(round(f.origin.y * 10) / 10), @(round(f.size.width * 10) / 10), @(round(f.size.height * 10) / 10) ];
}

// ---------------------------------------------------------------------------------------------------------------------
// focus
static NSDictionary* focus_info(void) {
	UIResponder* r = simax_first_responder();
	if (!r) return @{ @"focused": @NO };
	NSMutableDictionary* d = [NSMutableDictionary dictionary];
	NSString* cls = NSStringFromClass([r class]);
	d[@"focused"] = @YES;
	d[@"oid"] = simax_hex(r);
	d[@"class"] = cls;
	BOOL input = [r conformsToProtocol:@protocol(UIKeyInput)];
	d[@"text_input"] = @(input);
	NSString* kind = @"other";
	BOOL secure = NO;
	if ([cls containsString:@"WKContentView"]) kind = @"web";
	else if (isa_(r, @"UISearchTextField")) kind = @"searchfield";
	else if (isa_(r, @"UITextField")) {
		secure = [kv(r, @"secureTextEntry") boolValue];
		kind = secure ? @"securefield" : @"textfield";
	} else if (isa_(r, @"UITextView")) kind = @"textview";
	else if (input) kind = @"keyinput";
	d[@"kind"] = kind;
	if ([r isKindOfClass:[UIView class]]) {
		UIView* v = (UIView*)r;
		if (v.window) d[@"frame"] = rect_a(UIAccessibilityConvertFrameToScreenCoordinates(v.bounds, v));
		NSMutableArray* up = [NSMutableArray array];
		for (UIView* p = v.superview; p && up.count < 40; p = p.superview) [up addObject:simax_hex(p)];
		d[@"inside"] = up;
	}
	if (![kind isEqualToString:@"web"] && ![kind isEqualToString:@"other"]) {
		NSString* t = s_(kv(r, @"text"));
		if (t) d[@"value"] = secure ? [@"" stringByPaddingToLength:t.length withString:@"•" startingAtIndex:0] : t;
		NSString* ph = [r respondsToSelector:@selector(placeholder)] ? s_(((id(*)(id, SEL))objc_msgSend)(r, @selector(placeholder))) : nil;
		if (ph) d[@"placeholder"] = ph;
		NSString* l = s_([r accessibilityLabel]);
		if (l) d[@"label"] = l;
		NSString* i = s_(kv(r, @"accessibilityIdentifier"));
		if (i) d[@"id"] = i;
	}
	return d;
}

BOOL simax_actions_handle(NSString* op, NSDictionary* req, void (^reply)(NSDictionary*)) {
	if ([op isEqualToString:@"focus"]) { reply(focus_info()); return YES; }
	return NO;
}
