import Testing
import XCTest
import Core

// known issues: Xcode reports a test whose failure was expected as "Expected Failure" (not a failure), and one whose
// known issue did not occur as failed
@Test func knownIssue() {
    withKnownIssue("twice is off by one") {
        #expect(Core.twice(1) == 3)
    }
}

@Test func knownIssueNotRecorded() {
    withKnownIssue {
        #expect(Core.twice(1) == 2)
    }
}

@Test func knownIssueIntermittent() {
    withKnownIssue(isIntermittent: true) {
        #expect(Core.twice(2) == 4)
    }
}

struct Oops: Error {}

@Suite struct Known {
    @Test func thrown() {
        withKnownIssue {
            throw Oops()
        }
    }

    @Test func partly() {
        withKnownIssue {
            #expect(Core.twice(2) == 5)
        }
        #expect(Core.twice(3) == 7)
    }
}

final class DeltaXCTests: XCTestCase {
    func testExpectFailure() {
        XCTExpectFailure("known bug")
        XCTAssertEqual(Core.twice(1), 3)
    }

    func testExpectFailureBlock() {
        XCTExpectFailure("block form") {
            XCTFail("inside the block")
        }
    }

    func testExpectFailureNone() {
        XCTExpectFailure("nothing fails")
        XCTAssertEqual(Core.twice(1), 2)
    }
}
