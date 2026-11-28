#!/bin/bash
# x86Sim: run this package's tests on a phone (x86sim test --spm) with a set of -only-testing / -skip-testing
# selections and check each runs the tests Apple's simulator runs (Xcode 27.2, iOS 27.2 simulator on a Mac,
# xcodebuild test -scheme Multi with the same selection, 2026-11-28), with Apple's results, each test once. Exit 0
# when all match. positive(x:) and GammaTests' Second/check() fail on purpose; GammaTests has the same function
# names in two suites and a nested one (First/same(), Second/same(), Second/Inner/same()), told apart as Xcode does.
# DeltaTests has known issues: withKnownIssue and XCTExpectFailure are Apple's "Expected Failure" (expected_failure),
# testExpectFailureThrown's matched by a thrown error (no location: XCTest's stack at the throw gives it), a known
# issue that did not occur fails (knownIssueNotRecorded(), testExpectFailureNone, Known/partly() also fails outside
# its withKnownIssue). GammaTests' Values fail on purpose on an array, a dictionary, an optional and a struct (their
# values' children in the .xcresult: tests/xcresult/check.py).
#   tests/apps/XCTestDemo/spm-multi/check.sh <phone>
set -uo pipefail
X86SIM_ROOT=${X86SIM_ROOT:-$(cd "$(dirname "$0")/../../../.." && pwd)}
. "$X86SIM_ROOT/cli/lib/config.sh"
phone=${1:?usage: check.sh <phone>}
here=$(cd "$(dirname "$0")" && pwd)
OUT=$X86SIM_SCRATCH/xctest/spm-multi-$(date +%Y%m%d-%H%M%S); mkdir -p "$OUT"
# Apple's results: "### selection" then "Target identifier result" per test run (xcresulttool's identifier: a Swift
# Testing test by its suite path; XCTest methods without "()", as results.json has them; Apple's "Expected Failure"
# as expected_failure)
want=$(cat <<'EOF'
### (none)
AlphaTests AlphaSuite/inSuite() passed
AlphaTests AlphaSuite/other() passed
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
AlphaTests Common/t() passed
AlphaTests SharedXCTests/testAlphaSide passed
AlphaTests SharedXCTests/testShared passed
AlphaTests alphaOnly() passed
AlphaTests labelled(x:) passed
AlphaTests shared() passed
BetaTests BetaXCTests/testB1 passed
BetaTests Common/betaExtra() passed
BetaTests Common/t() passed
BetaTests SharedXCTests/testBetaSide passed
BetaTests SharedXCTests/testShared passed
BetaTests betaOnly() passed
BetaTests shared() passed
DeltaTests DeltaXCTests/testExpectFailure expected_failure
DeltaTests DeltaXCTests/testExpectFailureBlock expected_failure
DeltaTests DeltaXCTests/testExpectFailureNone failed
DeltaTests DeltaXCTests/testExpectFailureThrown expected_failure
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
DeltaTests knownIssue() expected_failure
DeltaTests knownIssueIntermittent() passed
DeltaTests knownIssueNotRecorded() failed
GammaTests First/check() passed
GammaTests First/same() passed
GammaTests Second/Inner/off() skipped
GammaTests Second/Inner/same() passed
GammaTests Second/check() failed
GammaTests Second/off() skipped
GammaTests Second/same() passed
GammaTests Values/array() failed
GammaTests Values/dictionary() failed
GammaTests Values/optional() failed
GammaTests Values/structure() failed
GammaTests gammaOnly() passed
GammaTests positive(x:) failed
GammaTests shared() passed
### -only-testing:BetaTests/betaOnly()
BetaTests betaOnly() passed
### -only-testing:AlphaTests/AlphaXCTests
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
### -skip-testing:AlphaTests/alphaOnly()
AlphaTests AlphaSuite/inSuite() passed
AlphaTests AlphaSuite/other() passed
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
AlphaTests Common/t() passed
AlphaTests SharedXCTests/testAlphaSide passed
AlphaTests SharedXCTests/testShared passed
AlphaTests labelled(x:) passed
AlphaTests shared() passed
BetaTests BetaXCTests/testB1 passed
BetaTests Common/betaExtra() passed
BetaTests Common/t() passed
BetaTests SharedXCTests/testBetaSide passed
BetaTests SharedXCTests/testShared passed
BetaTests betaOnly() passed
BetaTests shared() passed
DeltaTests DeltaXCTests/testExpectFailure expected_failure
DeltaTests DeltaXCTests/testExpectFailureBlock expected_failure
DeltaTests DeltaXCTests/testExpectFailureNone failed
DeltaTests DeltaXCTests/testExpectFailureThrown expected_failure
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
DeltaTests knownIssue() expected_failure
DeltaTests knownIssueIntermittent() passed
DeltaTests knownIssueNotRecorded() failed
GammaTests First/check() passed
GammaTests First/same() passed
GammaTests Second/Inner/off() skipped
GammaTests Second/Inner/same() passed
GammaTests Second/check() failed
GammaTests Second/off() skipped
GammaTests Second/same() passed
GammaTests Values/array() failed
GammaTests Values/dictionary() failed
GammaTests Values/optional() failed
GammaTests Values/structure() failed
GammaTests gammaOnly() passed
GammaTests positive(x:) failed
GammaTests shared() passed
### -skip-testing:BetaTests
AlphaTests AlphaSuite/inSuite() passed
AlphaTests AlphaSuite/other() passed
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
AlphaTests Common/t() passed
AlphaTests SharedXCTests/testAlphaSide passed
AlphaTests SharedXCTests/testShared passed
AlphaTests alphaOnly() passed
AlphaTests labelled(x:) passed
AlphaTests shared() passed
DeltaTests DeltaXCTests/testExpectFailure expected_failure
DeltaTests DeltaXCTests/testExpectFailureBlock expected_failure
DeltaTests DeltaXCTests/testExpectFailureNone failed
DeltaTests DeltaXCTests/testExpectFailureThrown expected_failure
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
DeltaTests knownIssue() expected_failure
DeltaTests knownIssueIntermittent() passed
DeltaTests knownIssueNotRecorded() failed
GammaTests First/check() passed
GammaTests First/same() passed
GammaTests Second/Inner/off() skipped
GammaTests Second/Inner/same() passed
GammaTests Second/check() failed
GammaTests Second/off() skipped
GammaTests Second/same() passed
GammaTests Values/array() failed
GammaTests Values/dictionary() failed
GammaTests Values/optional() failed
GammaTests Values/structure() failed
GammaTests gammaOnly() passed
GammaTests positive(x:) failed
GammaTests shared() passed
### -only-testing:AlphaTests/shared()
AlphaTests shared() passed
### -only-testing:BetaTests/SharedXCTests/testShared
BetaTests SharedXCTests/testShared passed
### -skip-testing:GammaTests/shared() -skip-testing:AlphaTests/SharedXCTests
AlphaTests AlphaSuite/inSuite() passed
AlphaTests AlphaSuite/other() passed
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
AlphaTests Common/t() passed
AlphaTests alphaOnly() passed
AlphaTests labelled(x:) passed
AlphaTests shared() passed
BetaTests BetaXCTests/testB1 passed
BetaTests Common/betaExtra() passed
BetaTests Common/t() passed
BetaTests SharedXCTests/testBetaSide passed
BetaTests SharedXCTests/testShared passed
BetaTests betaOnly() passed
BetaTests shared() passed
DeltaTests DeltaXCTests/testExpectFailure expected_failure
DeltaTests DeltaXCTests/testExpectFailureBlock expected_failure
DeltaTests DeltaXCTests/testExpectFailureNone failed
DeltaTests DeltaXCTests/testExpectFailureThrown expected_failure
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
DeltaTests knownIssue() expected_failure
DeltaTests knownIssueIntermittent() passed
DeltaTests knownIssueNotRecorded() failed
GammaTests First/check() passed
GammaTests First/same() passed
GammaTests Second/Inner/off() skipped
GammaTests Second/Inner/same() passed
GammaTests Second/check() failed
GammaTests Second/off() skipped
GammaTests Second/same() passed
GammaTests Values/array() failed
GammaTests Values/dictionary() failed
GammaTests Values/optional() failed
GammaTests Values/structure() failed
GammaTests gammaOnly() passed
GammaTests positive(x:) failed
### -only-testing:AlphaTests -skip-testing:AlphaTests/AlphaSuite/inSuite()
AlphaTests AlphaSuite/other() passed
AlphaTests AlphaXCTests/testA1 passed
AlphaTests AlphaXCTests/testA2 passed
AlphaTests Common/t() passed
AlphaTests SharedXCTests/testAlphaSide passed
AlphaTests SharedXCTests/testShared passed
AlphaTests alphaOnly() passed
AlphaTests labelled(x:) passed
AlphaTests shared() passed
### -only-testing:GammaTests/positive(x:)
GammaTests positive(x:) failed
### -only-testing:GammaTests/Second/same()
GammaTests Second/same() passed
### -only-testing:GammaTests/First
GammaTests First/check() passed
GammaTests First/same() passed
### -only-testing:GammaTests -skip-testing:GammaTests/Second/Inner
GammaTests First/check() passed
GammaTests First/same() passed
GammaTests Second/check() failed
GammaTests Second/off() skipped
GammaTests Second/same() passed
GammaTests Values/array() failed
GammaTests Values/dictionary() failed
GammaTests Values/optional() failed
GammaTests Values/structure() failed
GammaTests gammaOnly() passed
GammaTests positive(x:) failed
GammaTests shared() passed
### -only-testing:DeltaTests/Known
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
### -skip-testing:DeltaTests/DeltaXCTests/testExpectFailureNone -only-testing:DeltaTests
DeltaTests DeltaXCTests/testExpectFailure expected_failure
DeltaTests DeltaXCTests/testExpectFailureBlock expected_failure
DeltaTests DeltaXCTests/testExpectFailureThrown expected_failure
DeltaTests Known/partly() failed
DeltaTests Known/thrown() expected_failure
DeltaTests knownIssue() expected_failure
DeltaTests knownIssueIntermittent() passed
DeltaTests knownIssueNotRecorded() failed
EOF
)
n=0 bad=0
while IFS= read -r sel; do
	a=${sel#\#\#\# }; [ "$a" = "(none)" ] && a=""
	set -f; read -ra args <<< "$a"; set +f
	"$X86SIM_ROOT/cli/x86sim" test "$phone" --spm "$here" --out "$OUT/$n" --quiet "${args[@]}" > "$OUT/$n.txt" 2>&1 < /dev/null
	exp=$(awk -v s="$sel" '$0 == s {on = 1; next} /^###/ {on = 0} on' <<< "$want")
	python3 - "$OUT/$n/results.json" "$sel" "$exp" <<'PY' || bad=$((bad + 1))
import collections, json, sys
want = collections.Counter(l.strip() for l in sys.argv[3].splitlines() if l.strip())
got = collections.Counter()
try:
    for t in json.load(open(sys.argv[1]))["targets"]:
        for x in t["tests"]:
            got["%s %s %s" % (t["name"], x["identifier"], x["result"])] += 1
except (OSError, ValueError, KeyError) as e:
    print("BAD  %s: no results (%s)" % (sys.argv[2][4:], e)); sys.exit(1)
diff = ["%s: Apple %d, x86Sim %d" % (k, want[k], got[k]) for k in sorted(set(want) | set(got)) if want[k] != got[k]]
print("%-4s %s (%d tests)" % ("ok" if not diff else "BAD", sys.argv[2][4:], sum(want.values())))
for d in diff:
    print("       " + d)
sys.exit(1 if diff else 0)
PY
	n=$((n + 1))
done < <(grep '^###' <<< "$want")
echo "spm-multi: $([ "$bad" = 0 ] && echo "matches Apple's simulator" || echo "$bad selections differ") ($OUT)"
exit $((bad > 0))
