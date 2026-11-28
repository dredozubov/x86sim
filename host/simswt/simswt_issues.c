// x86Sim: the call stacks of XCTest issues that have no source location, for `x86sim test` (cli/libexec/xctest.py).
// A test that fails by throwing ("failed: caught error: ...") is recorded by XCTest with the stack it captured when
// the error was thrown (libXCTestSwiftSupport's swift_willThrow hook); on a Mac, XCTest symbolicates it with
// CoreSymbolication and reports the throwing line of the test method (Xcode: XCTestDemoTests.swift:35). Here that
// finds no symbols, so the issue's location stays empty and the log says "<unknown>:0". With X86SIM_SWT_ISSUES=<file>
// (set by xctest.py), -[XCTestCase recordIssue:] first writes such an issue's frames as one JSON line,
// {"test": "-[Class test]", "message": ..., "frames": [["<image path>", <offset>], ...]}; xctest.py symbolicates
// them on Linux (llvm-symbolizer + the test bundle's debug info) and takes the first frame in the test bundle.
// Expected failures (XCTExpectFailure): XCTest's log names only the file (no directory), so the observation center's
// -_testCase:didRecordExpectedFailure: also writes each one, {"test", "expected": true, "reason": its failure reason
// (null without one), "message", "file", "line"} (+ "frames" when the issue has no location).
#include <dlfcn.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char* iss_path;
static IMP iss_orig, iss_exp_orig;
static pthread_mutex_t iss_mu = PTHREAD_MUTEX_INITIALIZER;

static id iss_msg(id o, const char* sel)
{
	return o ? ((id (*)(id, SEL)) objc_msgSend)(o, sel_registerName(sel)) : NULL;
}

static const char* iss_cstr(id s)
{
	return s ? ((const char* (*)(id, SEL)) objc_msgSend)(s, sel_registerName("UTF8String")) : NULL;
}

static void iss_str(FILE* f, const char* s)
{
	fputc('"', f);
	for (; s && *s; s++) {
		unsigned char c = (unsigned char) *s;
		if (c == '"' || c == '\\') fprintf(f, "\\%c", c);
		else if (c < 0x20) fprintf(f, "\\u%04x", c);
		else fputc(c, f);
	}
	fputc('"', f);
}

static void iss_write(id self, id issue, id expected)
{
	id ctx = iss_msg(issue, "sourceCodeContext");
	id loc = iss_msg(ctx, "location");
	if (!expected && (!ctx || loc))
		return;   // located already (XCTAssert's file:line)
	id stack = iss_msg(ctx, "callStack");
	unsigned long n = stack ? ((unsigned long (*)(id, SEL)) objc_msgSend)(stack, sel_registerName("count")) : 0;
	if (!n && !expected)
		return;
	pthread_mutex_lock(&iss_mu);
	FILE* f = fopen(iss_path, "a");
	if (f) {
		fputs("{\"test\":", f);
		iss_str(f, iss_cstr(iss_msg(self, "name")));
		fputs(",\"message\":", f);
		iss_str(f, iss_cstr(iss_msg(issue, "compactDescription")));
		if (expected) {
			const char* why = iss_cstr(iss_msg(expected, "failureReason"));
			fputs(",\"expected\":true,\"reason\":", f);
			if (why) iss_str(f, why); else fputs("null", f);
			if (loc) {
				fputs(",\"file\":", f);
				iss_str(f, iss_cstr(iss_msg(iss_msg(loc, "fileURL"), "path")));
				fprintf(f, ",\"line\":%ld", ((long (*)(id, SEL)) objc_msgSend)(loc, sel_registerName("lineNumber")));
			}
		}
		fputs(",\"frames\":[", f);
		if (expected && loc)
			n = 0;   // located: no stack needed
		SEL at = sel_registerName("objectAtIndex:"), addr = sel_registerName("address");
		for (unsigned long i = 0; i < n && i < 64; i++) {
			id fr = ((id (*)(id, SEL, unsigned long)) objc_msgSend)(stack, at, i);
			uint64_t a = fr && class_respondsToSelector(object_getClass(fr), addr)
			             ? ((uint64_t (*)(id, SEL)) objc_msgSend)(fr, addr) : 0;
			Dl_info info;
			if (i) fputc(',', f);
			if (a && dladdr((const void*) (uintptr_t) a, &info) && info.dli_fname) {
				fputc('[', f);
				iss_str(f, info.dli_fname);
				fprintf(f, ",%llu]", (unsigned long long) (a - (uint64_t) (uintptr_t) info.dli_fbase));
			} else
				fprintf(f, "[null,%llu]", (unsigned long long) a);
		}
		fputs("]}\n", f);
		fclose(f);
	}
	pthread_mutex_unlock(&iss_mu);
}

static void iss_record(id self, SEL sel, id issue)
{
	iss_write(self, issue, NULL);
	((void (*)(id, SEL, id)) iss_orig)(self, sel, issue);
}

// -[XCTestObservationCenter _testCase:didRecordExpectedFailure:] (XCTExpectedFailure: failureReason, issue)
static void iss_expected(id self, SEL sel, id test, id expected)
{
	if (test && expected)
		iss_write(test, iss_msg(expected, "issue"), expected);
	((void (*)(id, SEL, id, id)) iss_exp_orig)(self, sel, test, expected);
}

static void iss_added(const struct mach_header* mh, intptr_t slide)
{
	if (!iss_orig) {
		Class c = objc_getClass("XCTestCase");
		Method m = c ? class_getInstanceMethod(c, sel_registerName("recordIssue:")) : NULL;
		if (m)
			iss_orig = method_setImplementation(m, (IMP) iss_record);
	}
	if (!iss_exp_orig) {
		Class c = objc_getClass("XCTestObservationCenter");
		Method m = c ? class_getInstanceMethod(c, sel_registerName("_testCase:didRecordExpectedFailure:")) : NULL;
		if (m)
			iss_exp_orig = method_setImplementation(m, (IMP) iss_expected);
	}
}

__attribute__((constructor)) static void iss_init(void)
{
	const char* p = getenv("X86SIM_SWT_ISSUES");
	if (!p || !*p)
		return;
	iss_path = strdup(p);
	_dyld_register_func_for_add_image(iss_added);
}
