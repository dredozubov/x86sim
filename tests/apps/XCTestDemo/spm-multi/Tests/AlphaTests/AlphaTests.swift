import Testing
import XCTest
import Core

final class AlphaXCTests: XCTestCase {
    func testA1() { XCTAssertEqual(Core.twice(1), 2) }
    func testA2() { XCTAssertEqual(Core.twice(2), 4) }
}

// the same class name in BetaTests
final class SharedXCTests: XCTestCase {
    func testShared() { XCTAssertEqual(Core.twice(0), 0) }
    func testAlphaSide() {}
}

@Test func alphaOnly() { #expect(Core.twice(3) == 6) }
@Test func shared() { #expect(true) }          // also in BetaTests
@Test(arguments: [1, 2]) func labelled(x: Int) { #expect(x > 0) }   // labelled arguments: f(x:)

@Suite struct AlphaSuite {
    @Test func inSuite() { #expect(Core.twice(4) == 8) }
    @Test func other() {}
}

@Suite struct Common {                          // also in BetaTests
    @Test func t() {}
}
