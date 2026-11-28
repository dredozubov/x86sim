"""cli/libexec/xctest.py: -only-testing / -skip-testing as Xcode 27.2 encodes them in the XCTestConfiguration it hands a
test process (read on a Mac from XCTestConfiguration.activeTestConfiguration inside the test, 2026-11-28), and which
target a selection is about. Offline: nothing runs on a phone.

Rows (expected values are Xcode's, copied from the captured configurations):
  1  "DumpXCTests"                -> run: o3 oc ocm a=nil, o1 oc a=nil, o0 a=nil (all c=[DumpXCTests])
  2  "DumpXCTests/testDump"       -> run: o2 ocm a=[] c=[DumpXCTests,testDump], o1 oc a=nil same c
  3  "DumpXCTests/testDump()"     -> run: o6 ocm os a=[] c=[DumpXCTests,testDump], o0 a=nil c=[DumpXCTests,testDump()]
  4  "dumpConfig()"               -> run: o0 a=nil c=[dumpConfig()]
  5  "DumpSuite/inSuite()"        -> as row 3 (a Swift Testing test in a suite)
  6  skip "CalcKitXCTests/testAdd" -> o2, o6, o1;  skip "meanOfNothing()" -> o0 only
  7  "f(x:)" (labelled arguments) -> o5 oc os (initWithSwiftTestingStringRepresentation's rule, disassembled)
  8  selection(): Target/Class/test() keeps its parentheses and the rest of the path; a SwiftPM bundle answers to its
     test targets' names (_modules); another target's selection leaves it out
  9  a Swift package with several test targets: SwiftPM's link of its one bundle (llbuild manifest) found and made
     into one test target's link (own object list, output, rpath for the flat layout, no other targets' AST paths,
     XCTest + libXCTestSwiftSupport as Xcode links every test bundle); its objects: the target's own and the
     non-test targets', not the other test targets' nor SwiftPM's runner.swift
 10  Swift Testing's log of a parameterized test (lines copied from a run): one test named f(x:), not
     "f(x:) with 2 test cases", its issue with its file:line
 11  Swift Testing's events (libsimswt, the shape of a run's GammaTests.swt.jsonl): the same function in two suites
     and a nested one -> one test each, identified as Xcode does (First/same(), Second/same(), Second/Inner/same(),
     top-level shared()); class Module.Suite..., results, failure file:line, skip comment + location, durations; a
     parameterized test's cases (Xcode's ?args= hash, argument, result); a line cut short ignored; console lines
     about those tests replaced, XCTest's kept
 12  issue texts as Xcode 27.2's .xcresult has them (Apple's, 2026-11-28): expectation + subexpressions whose value
     is not their own source, "<not evaluated>", ": comment", "Caught error: Oops()", "Issue recorded: a note"
 13  a thrown error's location: the first frame of its stack in the test bundle (.xctest), looked up one byte
     before its return address; the test found by -[Class test] without the module; nothing when nothing symbolicates
 14  known issues as Xcode 27.2 reports them (spm-multi's DeltaTests on Apple's simulator, 2026-11-28): withKnownIssue
     -> "expected_failure" with the issue and its comment as reason (libsimswt's "known"), a failed test keeps its
     known issues, a parameterized test's case too; "Known issue was not recorded" fails; XCTExpectFailure's console
     line (file name only, "Reason: (...)") and libsimswt's hook line (the path) -> expected_failure; Swift Testing's
     console "recorded a known issue"; counts' expected_failures; junit: not a failure
Mutants (each must fail its row; checked by hand when the test was written):
  M1  both XCTest method forms in a run list (the old double run)          -> rows 2, 3, 5
  M2  a=[] on the class form (made Swift Testing run every test)            -> row 1
  M3  test_identifiers strips "()" before splitting (the old encoding)      -> rows 3, 4, 5, 6
  M4  selection() strips "()" (the old selection)                           -> row 8
  M5  R_ST_END without " with N test cases" / R_ST_ISSUE without "with N argument(s)" -> row 10
  M6  SwiftPM's runner.swift object kept / no XCTest in a target's link     -> row 9
  M7  Swift Testing's tests keyed by function name (the old collapse)        -> row 11
  M8  every subexpression listed (literals too) / comment before the lines   -> row 12
  M9  the return address itself looked up / the first frame of any image     -> row 13
  M10 a known issue's test left "passed" (the old result) / its comment dropped -> row 14
"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path[:0] = [os.path.join(ROOT, "cli/libexec"), os.path.join(ROOT, "cli/lib")]
spec = importlib.util.spec_from_file_location("xctest_under_test", os.path.join(ROOT, "cli/libexec/xctest.py"))
X = importlib.util.module_from_spec(spec)
spec.loader.exec_module(X)


def ids(s, skip=False):
    out = []
    for o in X.test_identifiers(s, skip):
        d = o.fields
        out.append((d["o"], tuple(d["c"]), d["a"], tuple(k for k in ("oc", "ocm", "os") if d.get(k))))
    return out


class Identifiers(unittest.TestCase):
    def test_row1_class(self):
        c = ("DumpXCTests",)
        self.assertEqual(ids("DumpXCTests"), [(3, c, None, ("oc", "ocm")), (1, c, None, ("oc",)), (0, c, None, ())])

    def test_row2_method(self):
        c = ("DumpXCTests", "testDump")
        self.assertEqual(ids("DumpXCTests/testDump"), [(2, c, [], ("ocm",)), (1, c, None, ("oc",))])

    def test_row3_swift_method(self):
        self.assertEqual(ids("DumpXCTests/testDump()"), [(6, ("DumpXCTests", "testDump"), [], ("ocm", "os")),
                                                         (0, ("DumpXCTests", "testDump()"), None, ())])

    def test_row4_free_function(self):
        self.assertEqual(ids("dumpConfig()"), [(0, ("dumpConfig()",), None, ())])

    def test_row5_suite_test(self):
        self.assertEqual(ids("DumpSuite/inSuite()"), [(6, ("DumpSuite", "inSuite"), [], ("ocm", "os")),
                                                      (0, ("DumpSuite", "inSuite()"), None, ())])

    def test_row6_skips(self):
        c = ("CalcKitXCTests", "testAdd")
        self.assertEqual(ids("CalcKitXCTests/testAdd", skip=True),
                         [(2, c, [], ("ocm",)), (6, c, [], ("ocm", "os")), (1, c, None, ("oc",))])
        self.assertEqual(ids("meanOfNothing()", skip=True), [(0, ("meanOfNothing()",), None, ())])

    def test_row7_labelled_arguments(self):
        self.assertEqual(ids("f(x:)"), [(5, ("f(x:)",), None, ("oc", "os"))])


class Selection(unittest.TestCase):
    def test_row8_targets(self):
        t = {"_name": "CalcKitPackageTests", "_modules": ["CalcKitTests"]}
        names = {"CalcKitPackageTests", "CalcKitTests", "Other"}
        self.assertEqual(X.selection(t, ["CalcKitTests/Suite/test()"], [], names), (["Suite/test()"], []))
        self.assertEqual(X.selection(t, ["CalcKitPackageTests/C/m"], ["CalcKitTests/f()"], names), (["C/m"], ["f()"]))
        self.assertIsNone(X.selection(t, ["Other/C/m"], [], names))
        self.assertEqual(X.selection(t, [], ["CalcKitTests"], names), None)   # the whole target skipped


MANIFEST = """client:
  name: basic
commands:
  "C.Core-debug.module":
    tool: shell
    outputs: ["/b/Core.build/Core.swift.o"]
    args: ["/usr/bin/swiftc","-module-name","Core"]

  "C.MultiPackageTests-debug.test":
    tool: shell
    inputs: ["/b/AlphaTests.build/AlphaTests.swift.o"]
    outputs: ["/b/MultiPackageTests.xctest/Contents/MacOS/MultiPackageTests"]
    description: "Linking"
    args: ["/usr/bin/swiftc","-L","/b","-o","/b/MultiPackageTests.xctest/Contents/MacOS/MultiPackageTests","-Xlinker","-bundle","-Xlinker","-rpath","-Xlinker","@loader_path/../../../","@/b/MultiPackageTests.product/Objects.LinkFileList","-Xlinker","-add_ast_path","-Xlinker","/b/Modules/AlphaTests.swiftmodule","-Xlinker","-add_ast_path","-Xlinker","/b/Modules/BetaTests.swiftmodule","-Xlinker","-add_ast_path","-Xlinker","/b/Modules/Core.swiftmodule","-g"]

  "PackageStructure":
    tool: package-structure-tool
"""


class Split(unittest.TestCase):
    def test_row9_link(self):
        import tempfile
        with tempfile.NamedTemporaryFile("w", suffix=".yaml", delete=False) as f:
            f.write(MANIFEST)
        try:
            args = X.link_command(f.name, "/b/MultiPackageTests.xctest/Contents/MacOS/MultiPackageTests")
            self.assertIsNone(X.link_command(f.name, "/b/Other.xctest/Contents/MacOS/Other"))
        finally:
            os.unlink(f.name)
        self.assertEqual(args[:2], ["/usr/bin/swiftc", "-L"])
        got = X.split_link_args(args, "/b/x86sim-ios/AlphaTests.LinkFileList", "/b/x86sim-ios/AlphaTests.xctest/AlphaTests",
                                {"BetaTests.swiftmodule"})
        self.assertEqual(got, [
            "/usr/bin/swiftc", "-L", "/b", "-o", "/b/x86sim-ios/AlphaTests.xctest/AlphaTests", "-Xlinker", "-bundle",
            "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../", "@/b/x86sim-ios/AlphaTests.LinkFileList",
            "-Xlinker", "-add_ast_path", "-Xlinker", "/b/Modules/AlphaTests.swiftmodule",
            "-Xlinker", "-add_ast_path", "-Xlinker", "/b/Modules/Core.swiftmodule", "-g",
            "-framework", "XCTest", "-lXCTestSwiftSupport"])
        tests = [{"name": "AlphaTests", "c99name": "AlphaTests"}, {"name": "my-tests", "c99name": "my_tests"}]
        objs = ["/b/AlphaTests.build/AlphaTests.swift.o", "/b/AlphaTests.build/resource_bundle_accessor.swift.o",
                "/b/my-tests.build/T.swift.o", "/b/Core.build/Core.swift.o", "/b/MultiPackageTests.build/runner.swift.o"]
        self.assertEqual(X.target_objects(objs, "/b", tests, "my_tests", "MultiPackageTests"), objs[2:4])
        self.assertEqual(X.target_objects(objs, "/b", tests, "AlphaTests", "MultiPackageTests"), objs[:2] + objs[3:4])


class Log(unittest.TestCase):
    def test_row10_parameterized(self):
        p = X.Parser("GammaTests")
        for l in ["\u25c7 Test positive(x:) started.",
                  "\u2718 Test positive(x:) recorded an issue with 1 argument x \u2192 0 at GammaTests.swift:7:50: "
                  "Expectation failed: x > 0",
                  "\u2718 Test positive(x:) with 2 test cases failed after 0.008 seconds with 1 issue.",
                  "\u2714 Test labelled(x:) with 2 test cases passed after 0.005 seconds.",
                  "\u2718 Test run with 2 tests in 0 suites failed after 0.013 seconds with 1 issue."]:
            p.line(l)
        got = [(t["name"], t["result"], [(f["file"], f["line"]) for f in t["failures"]]) for t in p.tests]
        self.assertEqual(got, [("positive(x:)", "failed", [("GammaTests.swift", 7)]), ("labelled(x:)", "passed", [])])


def ev(kind, comps, payload=None, t=0.0, test=None, case=None, module="GammaTests", known=None):
    e = {"instant": {"suspending": {"seconds": int(t), "attoseconds": int(round((t % 1) * 1e18))}},
         "kind": {kind: payload or {}}, "testID": {"moduleName": module, "nameComponents": comps}}
    if case is not None:
        e["testCaseID"] = case
    d = {"event": e, "test": test or {}, "time": t}
    if known is not None:
        d["known"] = known
    return json.dumps(d)


def fn(comps, line, cases=None):
    return {"name": comps[-1], "parameters": [], "id": {"nameComponents": comps},
            "sourceLocation": {"filePath": "/p/Tests/GammaTests/GammaTests.swift", "line": line},
            "testCases": cases or [{"id": {"isStable": True}, "arguments": []}]}


LOC = lambda line, col=5: {"sourceContext": {"sourceLocation": {"filePath": "/p/Tests/GammaTests/GammaTests.swift",  # noqa: E731
                                                                "fileID": "GammaTests/GammaTests.swift", "line": line, "column": col},
                                             "backtrace": [1, 2]}}


def expectation(src, subs, comments=()):
    return dict(LOC(18, 26), comments=list(comments), isKnown=False, severity={"error": {}}, kind={"expectationFailed": {
        "expectation": {"evaluatedExpression": {"kind": {"generic": {"_0": src}}, "runtimeValue": {"description": "false"},
                                                "_subexpressions": [dict({"kind": {"generic": {"_0": a}}, "_subexpressions": []},
                                                                         **({"runtimeValue": {"description": b}} if b is not None else {}))
                                                                    for a, b in subs]}}}})


ARG1 = {"bytes": list(bytes.fromhex("6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b"))}
ARG0 = {"bytes": list(bytes.fromhex("5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9"))}


def arg_case(a, v):
    return {"id": {"argIDs": [a], "discriminator": 0, "isStable": True},
            "arguments": [{"parameter": {"firstName": "x", "typeInfo": {"unqualifiedName": "Int", "fullyQualifiedName": "Swift.Int"}},
                           "value": {"description": v, "debugDescription": v, "isCollection": False,
                                     "typeInfo": {"unqualifiedName": "Int", "fullyQualifiedName": "Swift.Int"}}}]}


class SwiftTestingEvents(unittest.TestCase):
    def lines(self):
        pos = fn(["positive(x:)"], 7, [arg_case(ARG1, "1"), arg_case(ARG0, "0")])
        c1, c0 = {"argIDs": [ARG1], "discriminator": 0}, {"argIDs": [ARG0], "discriminator": 0}
        out = [ev("testDiscovered", ["First"], test={"name": "First", "id": {"nameComponents": ["First"]}}),
               ev("runStarted", [])]
        for comps, line, t in ((["First", "same()"], 12, 1.0), (["Second", "same()"], 17, 2.0),
                               (["Second", "Inner", "same()"], 22, 3.0), (["shared()"], 6, 4.0)):
            out += [ev("testStarted", comps, t=t, test=fn(comps, line)), ev("testEnded", comps, t=t + 0.25, test=fn(comps, line))]
        out += [ev("testStarted", ["Second"], test={"name": "Second", "id": {"nameComponents": ["Second"]}}),
                ev("testStarted", ["Second", "check()"], t=5.0, test=fn(["Second", "check()"], 18)),
                ev("issueRecorded", ["Second", "check()"], {"_0": expectation("Core.twice(1) == 3", [("Core.twice(1)", "2"), ("3", "3")])},
                   t=5.1, test=fn(["Second", "check()"], 18)),
                ev("testEnded", ["Second", "check()"], t=5.5, test=fn(["Second", "check()"], 18)),
                ev("testSkipped", ["Second", "off()"], {"_0": dict(LOC(19, 40), comment="off on purpose")}, t=6.0,
                   test=fn(["Second", "off()"], 19)),
                ev("testStarted", ["positive(x:)"], t=7.0, test=pos),
                ev("testCaseStarted", ["positive(x:)"], t=7.0, test=pos, case=c1),
                ev("testCaseEnded", ["positive(x:)"], t=7.1, test=pos, case=c1),
                ev("testCaseStarted", ["positive(x:)"], t=7.1, test=pos, case=c0),
                ev("issueRecorded", ["positive(x:)"], {"_0": expectation("x > 0", [("x", "0"), ("0", "0")])}, t=7.2, test=pos, case=c0),
                ev("testCaseEnded", ["positive(x:)"], t=7.3, test=pos, case=c0),
                ev("testEnded", ["positive(x:)"], t=7.5, test=pos),
                ev("runEnded", []), '{"event": {"kind": {"testStar']
        return out

    def test_row11_suites_apart(self):
        got = {t["identifier"]: t for t in X.swift_testing_results(self.lines())}
        self.assertEqual(list(got), ["First/same()", "Second/same()", "Second/Inner/same()", "shared()", "Second/check()",
                                     "Second/off()", "positive(x:)"])
        self.assertEqual([(got[i]["class"], got[i]["name"], got[i]["suite"], got[i]["result"]) for i in got][:4],
                         [("GammaTests.First", "same()", ["First"], "passed"), ("GammaTests.Second", "same()", ["Second"], "passed"),
                          ("GammaTests.Second.Inner", "same()", ["Second", "Inner"], "passed"), ("GammaTests", "shared()", [], "passed")])
        self.assertEqual(got["First/same()"]["duration"], 0.25)
        c = got["Second/check()"]
        self.assertEqual((c["result"], [(f["file"], f["line"], f["message"]) for f in c["failures"]]),
                         ("failed", [("/p/Tests/GammaTests/GammaTests.swift", 18, "Expectation failed: Core.twice(1) == 3\nCore.twice(1) → 2")]))
        o = got["Second/off()"]
        self.assertEqual((o["result"], o["skip_message"], o["skip_line"]), ("skipped", "off on purpose", 19))
        p = got["positive(x:)"]
        self.assertEqual((p["result"], [(a["name"], a["id"][:8], a["result"], len(a["failures"])) for a in p["arguments"]]),
                         ("failed", [("1", "6b86b273", "passed", 0), ("0", "5feceb66", "failed", 1)]))
        self.assertEqual(p["arguments"][0]["args"][0]["label"], "x")
        self.assertIsNone(X.swift_testing_results(['{"cut sh']))

    def test_row11_parser_replaces_console(self):
        p = X.Parser("GammaTests")
        for l in ["Test Case '-[GammaTests.XT testA]' started.", "Test Case '-[GammaTests.XT testA]' passed (0.001 seconds).",
                  "✔ Test same() passed after 0.001 seconds.", "✔ Test same() passed after 0.001 seconds."]:
            p.line(l)
        self.assertEqual([t["identifier"] for t in p.tests], ["XT/testA", "SwiftTesting/same()"])
        with tempfile.TemporaryDirectory() as d:
            f = os.path.join(d, "e.jsonl")
            with open(f, "w") as fh:
                fh.write("\n".join(self.lines()) + "\n")
            p.swift_testing(f)
            empty = os.path.join(d, "none.jsonl")
            open(empty, "w").close()
            p.swift_testing(empty)   # no events (no libsimswt): nothing changes
        self.assertEqual([t["identifier"] for t in p.tests][:4], ["XT/testA", "First/same()", "Second/same()", "Second/Inner/same()"])


class IssueText(unittest.TestCase):
    def test_row12_apple_texts(self):
        m = X.st_issue_message
        self.assertEqual(m(expectation("k() == 2", [("k()", "1"), ("2", "2")], ["with a comment"])),
                         "Expectation failed: k() == 2\nk() → 1: with a comment")
        self.assertEqual(m(expectation("flag", [])), "Expectation failed: flag")
        e = expectation("Oops.self", [("Oops", None), ("self", None)])
        e["kind"]["expectationFailed"]["expectation"]["mismatchedErrorDescription"] = "an error was expected but none was thrown"
        self.assertEqual(m(e), "Expectation failed: an error was expected but none was thrown: Oops.self\n"
                               "Oops → <not evaluated>\nself → <not evaluated>")
        self.assertEqual(m({"kind": {"errorCaught": {"error": {"description": "Oops()"}}}, "comments": []}), "Caught error: Oops()")
        self.assertEqual(m({"kind": {"unconditional": {}}, "comments": ["a note"]}), "Issue recorded: a note")
        self.assertEqual(m({"kind": {"unconditional": {}}, "comments": []}), "Issue recorded")


class ThrowLocation(unittest.TestCase):
    def test_row13_frame(self):
        with tempfile.TemporaryDirectory() as d:
            b = os.path.join(d, "App.app/PlugIns/T.xctest/T")
            os.makedirs(os.path.dirname(b))
            open(b, "w").close()
            asked = []

            def sym(binary, offsets):
                asked.append((binary, offsets))
                return [None, ("/src/T.swift", 35, "f")]
            old = X.symbolize
            X.symbolize = sym
            try:
                other = [os.path.join(d, n) for n in ("XCTestCore", "libswiftCore.dylib", "CoreFoundation")]
                for o in other:   # images that are there too: only the test bundle's frames count
                    open(o, "w").close()
                frames = [[X.dv(other[0]), 100], [X.dv(other[1]), 200], [X.dv(b), 0x269b], [X.dv(b), 0x2753],
                          [X.dv(other[2]), 5]]
                self.assertEqual(X.throw_location(frames), ("/src/T.swift", 35))
                self.assertEqual(asked, [(b, [0x269a, 0x2752])])
                p = X.Parser("T")
                p.line("Test Case '-[T.HostTests testThrow]' started.")
                p.line('<unknown>:0: error: -[T.HostTests testThrow] : failed: caught error: "Oops()"')
                f = os.path.join(d, "i.jsonl")
                with open(f, "w") as fh:
                    fh.write(json.dumps({"test": "-[HostTests testThrow]", "message": 'failed: caught error: "Oops()"',
                                         "frames": frames}) + "\n")
                p.issue_stacks(f)
                self.assertEqual([(x["file"], x["line"]) for x in p.tests[0]["failures"]], [("/src/T.swift", 35)])
                X.symbolize = lambda binary, offsets: [None] * len(offsets)
                self.assertIsNone(X.throw_location(frames))
                self.assertIsNone(X.throw_location([[X.dv(other[0]), 100]]))
            finally:
                X.symbolize = old


class KnownIssues(unittest.TestCase):
    def test_row14_swift_testing(self):
        def known(src, subs, comment):   # an issue inside withKnownIssue: isKnown, libsimswt's "known" comment
            e = expectation(src, subs)
            e["isKnown"] = True
            return {"_0": e}, comment
        pos = fn(["each(x:)"], 40, [arg_case(ARG1, "1"), arg_case(ARG0, "0")])
        c1, c0 = {"argIDs": [ARG1], "discriminator": 0}, {"argIDs": [ARG0], "discriminator": 0}
        lines = []
        for comps, issues in ((["knownIssue()"], [known("Core.twice(1) == 3", [("Core.twice(1)", "2"), ("3", "3")], "twice is off by one")]),
                              (["knownIssueNotRecorded()"], [({"_0": dict(LOC(14, 20), comments=[], isKnown=False, severity={"error": {}},
                                                                         kind={"knownIssueNotRecorded": True})}, None)]),
                              (["Known", "partly()"], [known("Core.twice(2) == 5", [("Core.twice(2)", "4")], ""),
                                                       ({"_0": expectation("Core.twice(3) == 7", [("Core.twice(3)", "6")])}, None)])):
            lines.append(ev("testStarted", comps, test=fn(comps, 8)))
            lines += [ev("issueRecorded", comps, p, test=fn(comps, 8), known=k) for p, k in issues]
            lines.append(ev("testEnded", comps, test=fn(comps, 8)))
        lines += [ev("testStarted", ["each(x:)"], test=pos),
                  ev("testCaseStarted", ["each(x:)"], test=pos, case=c1), ev("testCaseEnded", ["each(x:)"], test=pos, case=c1),
                  ev("testCaseStarted", ["each(x:)"], test=pos, case=c0),
                  ev("issueRecorded", ["each(x:)"], known("x > 0", [("x", "0")], "zero")[0], test=pos, case=c0, known="zero"),
                  ev("testCaseEnded", ["each(x:)"], test=pos, case=c0), ev("testEnded", ["each(x:)"], test=pos)]
        got = {t["identifier"]: t for t in X.swift_testing_results(lines)}
        k = got["knownIssue()"]
        self.assertEqual((k["result"], k["failures"], [(f["line"], f["message"], f["reason"]) for f in k["expected_failures"]]),
                         ("expected_failure", [], [(18, "Expectation failed: Core.twice(1) == 3\nCore.twice(1) → 2", "twice is off by one")]))
        n = got["knownIssueNotRecorded()"]
        self.assertEqual((n["result"], [(f["line"], f["message"]) for f in n["failures"]], n.get("expected_failures")),
                         ("failed", [(14, "Known issue was not recorded")], None))
        p = got["Known/partly()"]
        self.assertEqual((p["result"], len(p["failures"]), [f["reason"] for f in p["expected_failures"]]), ("failed", 1, [None]))
        e = got["each(x:)"]
        self.assertEqual((e["result"], [a["result"] for a in e["arguments"]]), ("expected_failure", ["passed", "expected_failure"]))

    def test_row14_xctest_and_console(self):
        p = X.Parser("DeltaTests")
        for l in ["Test Case '-[DeltaTests.DeltaXCTests testExpectFailure]' started.",
                  'DeltaTests.swift:45: Expected failure in -[DeltaTests.DeltaXCTests testExpectFailure]: XCTAssertEqual failed: '
                  '("2") is not equal to ("3")Reason: (known bug)',
                  "Test Case '-[DeltaTests.DeltaXCTests testExpectFailure]' passed (0.915 seconds).",
                  "Test Case '-[DeltaTests.DeltaXCTests testBlock]' started.",
                  "DeltaTests.swift:50: Expected failure in -[DeltaTests.DeltaXCTests testBlock]: failed - inside the blockReason: (block form)",
                  "Test Case '-[DeltaTests.DeltaXCTests testBlock]' passed (0.009 seconds).",
                  "━ Test thrown() recorded a known issue at DeltaTests.swift:29:24: Caught error: Oops()",
                  "━ Test thrown() passed after 0.008 seconds with 1 known issue."]:
            self.assertTrue(p.line(l), l)
        with tempfile.TemporaryDirectory() as d:
            f = os.path.join(d, "i.jsonl")
            with open(f, "w") as fh:   # libsimswt's line for the first one only: the second keeps the console's
                fh.write(json.dumps({"test": "-[DeltaXCTests testExpectFailure]", "message": 'XCTAssertEqual failed: ("2") is not equal to ("3")',
                                     "expected": True, "reason": "known bug", "file": "/p/Tests/DeltaTests/DeltaTests.swift",
                                     "line": 45, "frames": []}) + "\n")
            p.issue_stacks(f)
        got = {t["identifier"]: t for t in p.tests}
        self.assertEqual([(i, t["result"], [(x["file"], x["line"], x["message"], x["reason"]) for x in t["expected_failures"]])
                          for i, t in got.items()],
                         [("DeltaXCTests/testExpectFailure", "expected_failure",
                           [("/p/Tests/DeltaTests/DeltaTests.swift", 45, 'XCTAssertEqual failed: ("2") is not equal to ("3")', "known bug")]),
                          ("DeltaXCTests/testBlock", "expected_failure", [("DeltaTests.swift", 50, "failed - inside the block", "block form")]),
                          ("SwiftTesting/thrown()", "expected_failure", [("DeltaTests.swift", 29, "Caught error: Oops()", None)])])
        run = type("R", (), {"phone": "p", "dev": "/d", "rt": "ios-27.2-24B8117-arm64", "plat": "ios", "out": "/o"})()
        s = X.summary(run, [{"name": "DeltaTests", "result": "passed", "duration": 1.0, "tests": p.tests}], 0)
        self.assertEqual((s["result"], s["counts"]), ("passed", {"passed": 0, "failed": 0, "skipped": 0, "expected_failures": 3, "total": 3}))
        j = X.junit(s)
        self.assertIn('failures="0"', j)
        self.assertNotIn("<failure", j)
        self.assertIn("Expected failure (known bug): /p/Tests/DeltaTests/DeltaTests.swift:45: XCTAssertEqual failed", j)


if __name__ == "__main__":
    unittest.main()
