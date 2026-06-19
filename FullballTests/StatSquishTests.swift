import Testing
@testable import Fullball

struct StatSquishTests {
    @Test func compressesTowardAnchorAndLowersCeiling() {
        // A top stat (99) drops well below itself; the ceiling is pulled down.
        #expect(StatSquish.value(99) < 90)
        #expect(StatSquish.value(99) > Int(StatSquish.anchor))
    }

    @Test func anchorIsRoughlyFixed() {
        let a = Int(StatSquish.anchor)
        #expect(abs(StatSquish.value(a) - a) <= 1)
    }

    @Test func staysInLegalRange() {
        for v in 1...99 {
            let r = StatSquish.value(v)
            #expect(r >= 1 && r <= 99)
        }
    }

    @Test func isMonotonic() {
        // Higher input never yields a lower output (ordering preserved).
        for v in 1..<99 {
            #expect(StatSquish.value(v) <= StatSquish.value(v + 1))
        }
    }

    @Test func belowAnchorBarelyMoves() {
        // The floor is preserved more than the ceiling — a low stat moves less
        // than a high stat (in absolute terms) since both compress toward anchor.
        let lowDelta  = abs(StatSquish.value(60) - 60)
        let highDelta = abs(StatSquish.value(99) - 99)
        #expect(highDelta > lowDelta)
    }
}
