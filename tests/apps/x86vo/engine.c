// x86vo's stand-in engine (Frameworks/Flutter.framework/Flutter): asks UIKit whether VoiceOver runs, as Flutter's
// engine does, and counts UIAccessibilityVoiceOverStatusDidChangeNotification.
#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

extern bool UIAccessibilityIsVoiceOverRunning(void);
extern const CFStringRef UIAccessibilityVoiceOverStatusDidChangeNotification;   // an NSString (toll-free bridged)
static int notified;

static void changed(CFNotificationCenterRef c, void* o, CFStringRef n, const void* obj, CFDictionaryRef info) { notified++; }

__attribute__((constructor)) static void init(void) {
	// NSNotificationCenter's default center posts through CoreFoundation's local center
	CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, changed,
		UIAccessibilityVoiceOverStatusDidChangeNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

int engine_voiceover(void) { return UIAccessibilityIsVoiceOverRunning(); }
int engine_notifications(void) { return notified; }
