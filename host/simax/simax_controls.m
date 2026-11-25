// x86Sim: simax's control requests for agents (set_value) (agent tools round 2; host side tools/launcher/core/src/axact.rs, protocol
// docs/protocols/SIMAX.md). Called from simax_actions.m's dispatch.
//
//   control oid            what control an element is (slider / switch / stepper / segmented / picker / datepicker /
//                          adjustable) and the values it takes: range, segments, each wheel's rows
//   setvalue oid value     sets the control to a value the way a touch would leave it: the control's value, then its
//                          ValueChanged actions (a picker wheel: the row selected and the delegate's didSelectRow), so
//                          the app (UIKit targets, SwiftUI bindings) hears it
#include <TargetConditionals.h>
#if TARGET_OS_WATCH
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_watchos
#define __API_UNAVAILABLE_PLATFORM_watchos watchos,introduced=2.0
#endif
#if TARGET_OS_TV
// tvOS's headers mark the pickers, sliders and switches unavailable; the code below only messages objects that are
// of those classes (looked up by name), which a tvOS process does not have
#include <AvailabilityInternal.h>
#undef __API_UNAVAILABLE_PLATFORM_tvos
#define __API_UNAVAILABLE_PLATFORM_tvos tvos,introduced=9.0
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
// controls
static NSArray<NSString*>* kControlClasses(void) {
	return @[ @"UISlider", @"UISwitch", @"UIStepper", @"UISegmentedControl", @"UIDatePicker", @"UIPickerView" ];
}

static BOOL is_control(id o) {
	for (NSString* c in kControlClasses())
		if (isa_(o, c)) return YES;
	return NO;
}

static UIView* view_up(id e) {
	id o = e;
	for (int i = 0; i < 24 && o; i++) {
		if ([o isKindOfClass:[UIView class]]) return o;
		@try { o = [o respondsToSelector:@selector(accessibilityContainer)] ? [o accessibilityContainer] : nil; } @catch (id ex) { o = nil; }
	}
	return nil;
}

static double overlap(CGRect a, CGRect b) {
	CGRect i = CGRectIntersection(a, b);
	if (CGRectIsNull(i)) return 0;
	double ai = i.size.width * i.size.height, au = a.size.width * a.size.height + b.size.width * b.size.height - ai;
	return au > 0 ? ai / au : 0;
}

// The UIKit control an accessibility element stands for: itself, a view it is inside (a picker's row is inside its
// UIPickerView), or (a SwiftUI node, an accessibility element over a hosted control) the control below it on the
// screen with the most overlap
static UIView* control_of(id e) {
	if (is_control(e)) return e;
	UIView* v = view_up(e);
	// up the views: the first control, but a date picker's own wheels (a UIPickerView inside it) stand for the date
	// picker
	UIView* first = nil;
	for (UIView* p = v; p; p = p.superview)
		if (is_control(p)) {
			if (isa_(p, @"UIDatePicker")) return p;
			if (!first) first = p;
		}
	if (first) return first;
	CGRect f = CGRectNull;
	@try { f = [e accessibilityFrame]; } @catch (id ex) { f = CGRectNull; }
	UIWindow* win = v.window;
	if (!win || CGRectIsNull(f)) return nil;
	UIView* best = nil;
	double score = 0;
	CGPoint c = CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
	NSMutableArray* stack = [NSMutableArray arrayWithObject:win];
	while (stack.count) {
		UIView* x = stack.lastObject;
		[stack removeLastObject];
		if (x.hidden || x.alpha < 0.01) continue;
		if (is_control(x)) {
			CGRect g = UIAccessibilityConvertFrameToScreenCoordinates(x.bounds, x);
			// the same place, the element's centre on it, or inside the element (a SwiftUI Toggle's node is the whole
			// row: its label and the switch at its end)
			double s = overlap(f, g) + (CGRectContainsPoint(g, c) ? 0.5 : 0) + (CGRectContainsRect(CGRectInset(f, -2, -2), g) ? 0.6 : 0);
			if (s > score) { score = s; best = x; }
			continue;
		}
		[stack addObjectsFromArray:x.subviews];
	}
	return score > 0.3 ? best : nil;
}

// a picker row's title: the data source's title / attributed title, else the text in the row's view
static NSString* text_in(UIView* v) {
	if (!v) return nil;
	NSString* t = s_(kv(v, @"text"));
	if (t && [v respondsToSelector:@selector(text)]) return t;
	NSString* l = s_(v.accessibilityLabel);
	if (l) return l;
	for (UIView* s in v.subviews) {
		NSString* x = text_in(s);
		if (x) return x;
	}
	return nil;
}

static NSString* picker_title(UIPickerView* p, NSInteger row, NSInteger comp) {
	id<UIPickerViewDelegate> d = p.delegate;
	@try {
		if ([d respondsToSelector:@selector(pickerView:titleForRow:forComponent:)]) {
			NSString* t = [d pickerView:p titleForRow:row forComponent:comp];
			if (t.length) return t;
		}
		if ([d respondsToSelector:@selector(pickerView:attributedTitleForRow:forComponent:)]) {
			NSString* t = [[d pickerView:p attributedTitleForRow:row forComponent:comp] string];
			if (t.length) return t;
		}
		UIView* v = [p viewForRow:row forComponent:comp];
		if (!v && [d respondsToSelector:@selector(pickerView:viewForRow:forComponent:reusingView:)])
			v = [d pickerView:p viewForRow:row forComponent:comp reusingView:nil];
		NSString* t = text_in(v);
		if (t.length) return t;
	} @catch (id ex) {
	}
	return nil;
}

// a wheel's rows by title; nil when the picker gives none (SwiftUI's wheels draw hosted views with no text in them)
static NSArray* picker_rows(UIPickerView* p, NSInteger comp, int limit) {
	NSMutableArray* a = [NSMutableArray array];
	NSInteger n = [p numberOfRowsInComponent:comp];
	int titled = 0;
	for (NSInteger r = 0; r < n && r < limit; r++) {
		NSString* t = picker_title(p, r, comp);
		if (t) titled++;
		[a addObject:t ?: [NSString stringWithFormat:@"#%ld", (long)r]];
	}
	return titled || !n ? a : nil;
}

static NSString* iso(NSDate* d, UIDatePickerMode m) {
	NSDateFormatter* f = [NSDateFormatter new];
	f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	f.dateFormat = m == UIDatePickerModeTime ? @"HH:mm" : m == UIDatePickerModeDate ? @"yyyy-MM-dd" : @"yyyy-MM-dd'T'HH:mm";
	return [f stringFromDate:d];
}

static NSDictionary* describe(UIView* c, id e) {
	NSMutableDictionary* d = [NSMutableDictionary dictionary];
	d[@"class"] = NSStringFromClass([c class]);
	if (isa_(c, @"UISlider")) {
		d[@"kind"] = @"slider";
		d[@"min"] = kv(c, @"minimumValue");
		d[@"max"] = kv(c, @"maximumValue");
		d[@"value"] = kv(c, @"value");
	} else if (isa_(c, @"UISwitch")) {
		d[@"kind"] = @"switch";
		d[@"value"] = [kv(c, @"on") boolValue] ? @"on" : @"off";
		d[@"values"] = @[ @"on", @"off" ];
	} else if (isa_(c, @"UIStepper")) {
		d[@"kind"] = @"stepper";
		d[@"min"] = kv(c, @"minimumValue");
		d[@"max"] = kv(c, @"maximumValue");
		d[@"step"] = kv(c, @"stepValue");
		d[@"value"] = kv(c, @"value");
	} else if (isa_(c, @"UISegmentedControl")) {
		UISegmentedControl* s = (UISegmentedControl*)c;
		d[@"kind"] = @"segmented";
		NSMutableArray* t = [NSMutableArray array];
		for (NSUInteger i = 0; i < s.numberOfSegments; i++) {
			NSString* x = [s titleForSegmentAtIndex:i];
			if (!x.length) x = s_([[s imageForSegmentAtIndex:i] accessibilityLabel]);
			[t addObject:x ?: [NSString stringWithFormat:@"%lu", (unsigned long)i]];
		}
		d[@"values"] = t;
		if (s.selectedSegmentIndex >= 0 && s.selectedSegmentIndex < (NSInteger)t.count) d[@"value"] = t[s.selectedSegmentIndex];
	} else if (isa_(c, @"UIDatePicker")) {
		UIDatePicker* p = (UIDatePicker*)c;
		d[@"kind"] = @"datepicker";
		UIDatePickerMode m = p.datePickerMode;
		d[@"mode"] = m == UIDatePickerModeTime ? @"time" : m == UIDatePickerModeDate ? @"date" : m == UIDatePickerModeCountDownTimer ? @"countdown" : @"dateAndTime";
		d[@"value"] = iso(p.date, m);
		if (p.minimumDate) d[@"min"] = iso(p.minimumDate, m);
		if (p.maximumDate) d[@"max"] = iso(p.maximumDate, m);
	} else if (isa_(c, @"UIPickerView")) {
		UIPickerView* p = (UIPickerView*)c;
		d[@"kind"] = @"picker";
		NSMutableArray* comps = [NSMutableArray array];
		NSMutableArray* sel = [NSMutableArray array];
		BOOL titles = YES;
		for (NSInteger i = 0; i < p.numberOfComponents; i++) {
			NSArray* rows = picker_rows(p, i, 400);
			if (!rows) titles = NO;
			[comps addObject:rows ?: @[]];
			NSInteger r = [p selectedRowInComponent:i];
			[sel addObject:(r >= 0 ? picker_title(p, r, i) : nil) ?: @""];
		}
		d[@"components"] = comps;
		d[@"titles"] = @(titles);
		NSString* v = [sel componentsJoinedByString:@", "];
		// no titles: what the wheel's accessibility value says (VoiceOver reads the row there)
		if (!titles) v = s_([e accessibilityValue]) ?: v;
		d[@"value"] = v;
	}
	return d;
}

static void changed(UIView* c) {
	if ([c isKindOfClass:[UIControl class]]) [(UIControl*)c sendActionsForControlEvents:UIControlEventValueChanged];
}

static NSString* norm(NSString* s) {
	return [[s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
}

// a row by label: exact, then prefix, then contains (case-insensitive); or a row number
static NSInteger row_of(NSArray<NSString*>* rows, NSString* want) {
	NSString* w = norm(want);
	for (int pass = 0; pass < 3; pass++)
		for (NSUInteger i = 0; i < rows.count; i++) {
			NSString* r = norm(rows[i]);
			if ((pass == 0 && [r isEqualToString:w]) || (pass == 1 && [r hasPrefix:w]) || (pass == 2 && [r containsString:w])) return i;
		}
	NSScanner* sc = [NSScanner scannerWithString:w];
	NSInteger n;
	if ([w hasPrefix:@"#"] && [[NSScanner scannerWithString:[w substringFromIndex:1]] scanInteger:&n] && n >= 0 && n < (NSInteger)rows.count) return n;
	(void)sc;
	return -1;
}

static NSDate* parse_date(NSString* s, NSDate* base) {
	NSDateFormatter* f = [NSDateFormatter new];
	f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
	for (NSString* fmt in @[ @"yyyy-MM-dd'T'HH:mm:ss", @"yyyy-MM-dd'T'HH:mm", @"yyyy-MM-dd HH:mm", @"yyyy-MM-dd" ]) {
		f.dateFormat = fmt;
		NSDate* d = [f dateFromString:s];
		if (d) return d;
	}
	// a time alone: that time on the picker's day
	for (NSString* fmt in @[ @"HH:mm:ss", @"HH:mm", @"h:mm a" ]) {
		f.dateFormat = fmt;
		NSDate* t = [f dateFromString:s];
		if (!t) continue;
		NSCalendar* cal = NSCalendar.currentCalendar;
		NSDateComponents* tc = [cal components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:t];
		return [cal dateBySettingHour:tc.hour minute:tc.minute second:tc.second ofDate:base ?: [NSDate date] options:0];
	}
	return nil;
}

static BOOL truthy(NSString* v, BOOL* out) {
	NSString* s = norm(v);
	if ([@[ @"on", @"1", @"true", @"yes" ] containsObject:s]) { *out = YES; return YES; }
	if ([@[ @"off", @"0", @"false", @"no" ] containsObject:s]) { *out = NO; return YES; }
	return NO;
}

// a number, or a percentage of [min, max] ("50%")
static BOOL number(NSString* v, double min, double max, double* out) {
	NSString* s = norm(v);
	BOOL pct = [s hasSuffix:@"%"];
	if (pct) s = [s substringToIndex:s.length - 1];
	NSScanner* sc = [NSScanner scannerWithString:s];
	double x;
	if (![sc scanDouble:&x] || !sc.isAtEnd) return NO;
	*out = pct ? min + (max - min) * x / 100.0 : x;
	return YES;
}

static NSDictionary* err(NSString* fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static NSDictionary* err(NSString* fmt, ...) {
	va_list ap;
	va_start(ap, fmt);
	NSString* s = [[NSString alloc] initWithFormat:fmt arguments:ap];
	va_end(ap);
	return @{ @"error": s };
}

// a control SwiftUI made (inside a hosting view): its UIKit value is SwiftUI's own mapping, not the app's
static BOOL hosted(UIView* v) {
	for (UIView* p = v.superview; p; p = p.superview) {
		NSString* c = NSStringFromClass([p class]);
		if ([c hasPrefix:@"SwiftUI."] || [c hasPrefix:@"_TtC7SwiftUI"] || [c containsString:@"HostingView"] || [c containsString:@"PlatformViewHost"]) return YES;
	}
	return NO;
}

static NSDictionary* set_adjustable(id e, NSString* want) {
	// increment / decrement until the value reads as asked (numbers: towards it; text: one way, then the other)
	NSString* (^val)(void) = ^NSString* { @try { return s_([e accessibilityValue]) ?: @""; } @catch (id ex) { return @""; } };
	NSString* w = norm(want);
	double target = 0;
	BOOL numeric = number(want, 0, 100, &target) && ![want hasSuffix:@"%"];
	NSString* start = val();
	if ([norm(start) isEqualToString:w]) return @{ @"kind": @"adjustable", @"value": start, @"steps": @0 };
	int steps = 0;
	for (int dir = 0; dir < 2; dir++) {
		NSString* last = val();
		for (int i = 0; i < 300; i++) {
			BOOL up = dir == 0;
			if (numeric) {
				double cur;
				if (number(last, 0, 100, &cur)) up = cur < target;
			}
			@try { if (up) [e accessibilityIncrement]; else [e accessibilityDecrement]; } @catch (id ex) { break; }
			steps++;
			NSString* now = val();
			if ([norm(now) isEqualToString:w] || ([norm(now) hasPrefix:w] && w.length)) return @{ @"kind": @"adjustable", @"value": now, @"steps": @(steps) };
			if (numeric) {
				double cur;
				if (number(now, 0, 100, &cur) && ((up && cur > target) || (!up && cur < target))) return @{ @"kind": @"adjustable", @"value": now, @"steps": @(steps), @"note": @"nearest value" };
			}
			if ([now isEqualToString:last]) break;   // at the end
			last = now;
		}
		if (numeric) break;
	}
	return err(@"adjustable element: no value %@ reached by increment / decrement (it reads %@ now, started at %@)", want, val(), start);
}

static NSDictionary* set_value(NSDictionary* req) {
	NSString* oid = req[@"oid"];
	if ([oid rangeOfString:@"#"].location != NSNotFound) return err(@"web content: set_value works on native controls (tap / type into web fields)");
	id e = simax_find_oid(oid);
	if (!e) return err(@"element gone");
	id raw = req[@"value"];
	NSString* want = [raw isKindOfClass:[NSArray class]] ? [(NSArray*)raw componentsJoinedByString:@", "] : s_(raw) ?: @"";
	UIView* c = control_of(e);
	if (!c) {
		uint64_t t = 0;
		@try { t = [e accessibilityTraits]; } @catch (id ex) { t = 0; }
		if (t & UIAccessibilityTraitAdjustable) return set_adjustable(e, want);
		return err(@"not a control set_value knows (slider, switch, stepper, segmented control, picker, date picker, or an adjustable element): %@", NSStringFromClass([e class]));
	}
	NSMutableDictionary* before = [describe(c, e) mutableCopy];
	NSString* kind = before[@"kind"];
	if ([kind isEqualToString:@"slider"]) {
		UISlider* s = (UISlider*)c;
		double x;
		if (!number(want, s.minimumValue, s.maximumValue, &x)) return err(@"slider: a number from %g to %g, or a percentage (\"50%%\")", s.minimumValue, s.maximumValue);
		if (x < s.minimumValue || x > s.maximumValue) {
			if (s.minimumValue == 0 && s.maximumValue == 1 && hosted(s))
				return err(@"slider: %g is outside 0 to 1, the range SwiftUI gives its UISlider (it maps that onto the app's own range): give a percentage of the range, e.g. \"%g%%\"", x, x);
			return err(@"slider: %g is outside its range %g to %g", x, s.minimumValue, s.maximumValue);
		}
		[s setValue:x animated:NO];
		changed(s);
	} else if ([kind isEqualToString:@"switch"]) {
		BOOL on;
		if (!truthy(want, &on)) return err(@"switch: on or off");
		UISwitch* s = (UISwitch*)c;
		if (s.on != on) {
			[s setOn:on animated:NO];
			changed(s);
		}
	} else if ([kind isEqualToString:@"stepper"]) {
		UIStepper* s = (UIStepper*)c;
		NSString* w = norm(want);
		// "+3" / "-2": that many taps on + / -
		if ([w hasPrefix:@"+"] || ([w hasPrefix:@"-"] && hosted(s))) {
			NSInteger n = [[w substringFromIndex:[w hasPrefix:@"+"] ? 1 : 0] integerValue];
			for (NSInteger i = 0; i < labs(n) && i < 1000; i++) {
				double nv = s.value + (n > 0 ? s.stepValue : -s.stepValue);
				if (nv > s.maximumValue || nv < s.minimumValue) {
					if (!hosted(s)) break;
					s.value = (s.minimumValue + s.maximumValue) / 2;   // SwiftUI's stepper counts by itself: re-centre
					nv = s.value + (n > 0 ? s.stepValue : -s.stepValue);
				}
				s.value = nv;
				changed(s);
			}
			NSMutableDictionary* d = [describe(c, e) mutableCopy];
			d[@"steps"] = @(n);
			d[@"was"] = before[@"value"] ?: @"";
			if (hosted(s)) { [d removeObjectForKey:@"value"]; d[@"swiftui"] = @YES; }
			return d;
		}
		// SwiftUI's Stepper keeps its own count (its UIStepper only says + or -): the host steps, reading the count
		if (hosted(s)) return @{ @"error": @"stepper: SwiftUI's stepper keeps its count in the app: step it with +N / -N", @"kind": @"stepper", @"swiftui": @YES };
		double x;
		if (!number(want, s.minimumValue, s.maximumValue, &x)) return err(@"stepper: a number from %g to %g in steps of %g", s.minimumValue, s.maximumValue, s.stepValue);
		if (x < s.minimumValue || x > s.maximumValue) return err(@"stepper: %g is outside %g to %g", x, s.minimumValue, s.maximumValue);
		// one step at a time, as taps on + / - would (an app may count its ValueChanged events)
		int n = 0;
		while (fabs(s.value - x) >= s.stepValue / 2 && n++ < 1000) {
			s.value = s.value + (x > s.value ? s.stepValue : -s.stepValue);
			changed(s);
		}
	} else if ([kind isEqualToString:@"segmented"]) {
		UISegmentedControl* s = (UISegmentedControl*)c;
		NSInteger i = row_of(before[@"values"], want);
		if (i < 0) return err(@"segmented control: one of %@", [before[@"values"] componentsJoinedByString:@", "]);
		if (s.selectedSegmentIndex != i) {
			s.selectedSegmentIndex = i;
			changed(s);
		}
	} else if ([kind isEqualToString:@"datepicker"]) {
		UIDatePicker* p = (UIDatePicker*)c;
		NSDate* d = parse_date(want, p.date);
		if (!d) return err(@"date picker (%@): a date as 2026-05-01, 2026-05-01T14:30 or a time 14:30", before[@"mode"]);
		if ((p.minimumDate && [d compare:p.minimumDate] == NSOrderedAscending) || (p.maximumDate && [d compare:p.maximumDate] == NSOrderedDescending))
			return err(@"date picker: %@ is outside %@ to %@", want, before[@"min"] ?: @"-", before[@"max"] ?: @"-");
		[p setDate:d animated:NO];
		changed(p);
	} else if ([kind isEqualToString:@"picker"]) {
		UIPickerView* p = (UIPickerView*)c;
		NSArray* comps = before[@"components"];
		// rows without titles: the wheel the element is, stepped row by row as VoiceOver's swipes do (the picker
		// selects each row and tells its delegate)
		// rows without titles (SwiftUI's wheels draw hosted views): "#N" selects row N of the wheel the element is
		// (quiet: without telling the delegate, while the host reads each row's text from the wheel's value); text: the
		// host searches the rows that way
		if (![before[@"titles"] boolValue]) {
			NSInteger comp = 0;
			if (p.numberOfComponents > 1) {
				CGRect f = CGRectNull;
				@try { f = [e accessibilityFrame]; } @catch (id ex) { f = CGRectNull; }
				CGRect pf = UIAccessibilityConvertFrameToScreenCoordinates(p.bounds, p);
				double x = pf.origin.x, cx = CGRectGetMidX(f), total = 0;
				for (NSInteger i = 0; i < p.numberOfComponents; i++) total += [p rowSizeForComponent:i].width;
				double pad = MAX(0, (pf.size.width - total) / 2);
				x += pad;
				for (NSInteger i = 0; i < p.numberOfComponents; i++) {
					x += [p rowSizeForComponent:i].width;
					if (cx < x) { comp = i; break; }
				}
			}
			NSInteger n = [p numberOfRowsInComponent:comp];
			NSScanner* sc = [NSScanner scannerWithString:[want hasPrefix:@"#"] ? [want substringFromIndex:1] : @""];
			NSInteger row;
			if (![want hasPrefix:@"#"] || ![sc scanInteger:&row] || row < 0 || row >= n)
				return @{ @"error": @"picker: its rows have no titles", @"kind": @"picker", @"titles": @NO, @"rows": @(n),
					@"row": @([p selectedRowInComponent:comp]), @"component": @(comp) };
			[p selectRow:row inComponent:comp animated:NO];
			if (![req[@"quiet"] boolValue] && [p.delegate respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)])
				[p.delegate pickerView:p didSelectRow:row inComponent:comp];
			return @{ @"kind": @"picker", @"row": @(row), @"rows": @(n), @"component": @(comp), @"was": before[@"value"] ?: @"" };
		}
		NSArray* parts = [raw isKindOfClass:[NSArray class]] ? raw : (comps.count > 1 ? [want componentsSeparatedByString:@","] : @[ want ]);
		if (parts.count > comps.count) return err(@"picker: %lu wheel(s), %lu values given", (unsigned long)comps.count, (unsigned long)parts.count);
		NSMutableArray* rows = [NSMutableArray array];
		for (NSUInteger i = 0; i < parts.count; i++) {
			NSString* w = s_(parts[i]) ?: @"";
			if (!norm(w).length) { [rows addObject:@(-1)]; continue; }   // "" keeps that wheel
			NSInteger r = row_of(comps[i], w);
			if (r < 0) {
				NSArray* some = comps[i];
				if (some.count > 40) some = [some subarrayWithRange:NSMakeRange(0, 40)];
				return err(@"picker wheel %lu: no row %@ (rows: %@%@)", (unsigned long)i + 1, w, [some componentsJoinedByString:@", "], [comps[i] count] > 40 ? @", ..." : @"");
			}
			[rows addObject:@(r)];
		}
		for (NSUInteger i = 0; i < rows.count; i++) {
			NSInteger r = [rows[i] integerValue];
			if (r < 0 || [p selectedRowInComponent:i] == r) continue;
			[p selectRow:r inComponent:i animated:NO];
			// what a scroll of the wheel ends with: the delegate hears the row (SwiftUI's Picker binding is set there)
			if ([p.delegate respondsToSelector:@selector(pickerView:didSelectRow:inComponent:)]) [p.delegate pickerView:p didSelectRow:r inComponent:i];
		}
	}
	NSMutableDictionary* after = [describe(c, e) mutableCopy];
	after[@"was"] = before[@"value"] ?: @"";
	[after removeObjectForKey:@"components"];
	return after;
}

static NSDictionary* control_info(NSDictionary* req) {
	id e = simax_find_oid(req[@"oid"] ?: @"");
	if (!e) return err(@"element gone");
	UIView* c = control_of(e);
	if (c) return describe(c, e);
	uint64_t t = 0;
	@try { t = [e accessibilityTraits]; } @catch (id ex) { t = 0; }
	if (t & UIAccessibilityTraitAdjustable) return @{ @"kind": @"adjustable", @"value": s_([e accessibilityValue]) ?: @"" };
	return @{ @"kind": @"none", @"class": NSStringFromClass([e class]) };
}

BOOL simax_controls_handle(NSString* op, NSDictionary* req, void (^reply)(NSDictionary*)) {
	if ([op isEqualToString:@"control"]) { reply(control_info(req)); return YES; }
	if ([op isEqualToString:@"setvalue"]) { reply(set_value(req)); return YES; }
	return NO;
}
