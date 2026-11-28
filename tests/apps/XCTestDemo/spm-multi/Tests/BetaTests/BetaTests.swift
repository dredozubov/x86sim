import Testing
import XCTest
import Core

final class BetaXCTests: XCTestCase {
    func testB1() { XCTAssertEqual(Core.twice(5), 10) }
}

final class SharedXCTests: XCTestCase {          // also in AlphaTests
    func testShared() {}
    func testBetaSide() {}
}

@Test func betaOnly() {}
@Test func shared() {}                           // also in AlphaTests

@Suite struct Common {                           // also in AlphaTests
    @Test func t() {}
    @Test func betaExtra() {}
}
