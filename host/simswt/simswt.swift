// x86Sim: Swift Testing's events for `x86sim test` (cli/libexec/xctest.py). XCTest runs a target's Swift Testing tests
// in its own process (libXCTestSwiftSupport: Testing.Runner with an event handler of its own) and, without an IDE
// session, only prints them through Event.ConsoleOutputRecorder ("✔ Test same() passed ..."): lines that name no
// suite and interleave when tests run in parallel, so tests of the same name in two suites could not be told apart.
// libsimswt (inserted into the test process by xctest.py) interposes ConsoleOutputRecorder.record(_:in:) and, before
// it prints, writes the event as one JSON line to $X86SIM_SWT_EVENTS: {"event": Event.Snapshot, "test": the event's
// Test.Snapshot, "time": wall clock} with Swift Testing's own Codable encoding (test IDs with module, suite path and
// source location, issues with their source location and expression, skip comments, instants), and for a known
// issue "known": its withKnownIssue comment ("" without one; Issue.Snapshot keeps only isKnown).
import Testing   // with the SPI declarations of Testing-SPI.swiftinterface (build.sh)
import Foundation

private let out: Int32 = {
    guard let p = getenv("X86SIM_SWT_EVENTS") else { return -1 }
    return open(p, O_WRONLY | O_CREAT | O_APPEND, 0o644)
}()
private let lock = NSLock()

private struct Line: Encodable {
    var event: Event.Snapshot
    var test: Test.Snapshot?
    var time: Double
    var known: String?
}

private func knownComment(_ event: Event) -> String? {
    guard case .issueRecorded(let issue) = event.kind, let ctx = issue.knownIssueContext else { return nil }
    return ctx.comment?.rawValue ?? ""
}

extension Event.ConsoleOutputRecorder {
    // the same signature as record(_:in:) (self, the event and the context by reference): the interposer
    // (simswt_interpose.c) puts it in place of Testing's for every image but this one, so record() here is Testing's
    @_silgen_name("x86sim_swt_record")
    func x86simRecord(_ event: Event, in context: Event.Context) -> Bool {
        if out >= 0 {
            let line = Line(event: Event.Snapshot(snapshotting: event), test: context.test.map { Test.Snapshot(snapshotting: $0) },
                            time: Date().timeIntervalSince1970, known: knownComment(event))
            if var d = try? JSONEncoder().encode(line) {
                d.append(10)
                lock.lock()
                d.withUnsafeBytes { _ = write(out, $0.baseAddress, $0.count) }
                lock.unlock()
            }
        }
        return record(event, in: context)
    }
}
