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

// failing #expect on structured values (fail on purpose): Xcode keeps a value's label and children (an array's
// elements, a dictionary's pairs, an optional's wrapped value, a struct's stored properties)
struct Point: Equatable { var x: Int; var y: Int }

@Suite struct Values {
    @Test func array() { #expect([1, 2, 3] == [Core.twice(1), 2, 4]) }
    @Test func dictionary() { #expect(["b": Core.twice(1)] == ["b": 3]) }   // one key: a dictionary's order varies by process
    @Test func optional() { let v: Int? = Core.twice(1); #expect(v == nil) }
    @Test func structure() { #expect(Point(x: 1, y: Core.twice(1)) == Point(x: 1, y: 3)) }
}
