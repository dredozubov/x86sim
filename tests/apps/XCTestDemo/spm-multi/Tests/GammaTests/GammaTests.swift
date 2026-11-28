import Testing
import Core

// Swift Testing only
@Test func gammaOnly() {}
@Test func shared() {}                           // also in AlphaTests and BetaTests
@Test(arguments: [1, 0]) func positive(x: Int) { #expect(x > 0) }   // fails on purpose for 0

// the same test names in two suites of this target and a nested one: Xcode tells them apart by their suite path
// (First/same(), Second/same(), Second/Inner/same()); Second's check() fails on purpose, First's passes
@Suite struct First {
    @Test func same() {}
    @Test func check() { #expect(Core.twice(1) == 2) }
}

@Suite struct Second {
    @Test func same() {}
    @Test func check() { #expect(Core.twice(1) == 3) }
    @Test(.disabled("off on purpose")) func off() {}

    @Suite struct Inner {
        @Test func same() {}
        @Test(.disabled("inner off")) func off() {}
    }
}
