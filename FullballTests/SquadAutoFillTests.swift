import Testing
@testable import Fullball

struct SquadAutoFillTests {
    typealias C = SquadAutoFill.Candidate
    let slots: [Position] = OffPosition.slots   // [.gk, .def, .mid, .mid, .fwd]

    @Test func picksBestNaturalFitPerSlot() {
        let cands = [
            C(id: "gk1", position: .gk, rating: 70),
            C(id: "gk2", position: .gk, rating: 80),   // better keeper
            C(id: "d1",  position: .def, rating: 75),
            C(id: "m1",  position: .mid, rating: 88),
            C(id: "m2",  position: .mid, rating: 60),
            C(id: "f1",  position: .fwd, rating: 90),
        ]
        let r = SquadAutoFill.pick(slots: slots, from: cands)
        #expect(r == ["gk2", "d1", "m1", "m2", "f1"])
    }

    @Test func backfillsEmptySlotsOffPositionWithBestRemaining() {
        // No defender owned; the strongest leftover fills the DEF slot.
        let cands = [
            C(id: "gk1", position: .gk, rating: 70),
            C(id: "m1",  position: .mid, rating: 85),
            C(id: "m2",  position: .mid, rating: 80),
            C(id: "f1",  position: .fwd, rating: 90),
        ]
        let r = SquadAutoFill.pick(slots: slots, from: cands)
        #expect(r[0] == "gk1")            // gk slot
        #expect(r[2] == "m1" || r[3] == "m1")   // a mid slot keeps a natural mid
        // DEF slot (index 1) backfilled with the best remaining (the fwd) and a
        // mid; the last fwd slot gets whatever is left. No candidate reused.
        let used = r.compactMap { $0 }
        #expect(Set(used).count == used.count)
        #expect(used.contains("f1"))
    }

    @Test func neverReusesACandidate() {
        let cands = (0..<3).map { C(id: "p\($0)", position: .mid, rating: 50 + $0) }
        let r = SquadAutoFill.pick(slots: slots, from: cands)
        let used = r.compactMap { $0 }
        #expect(used.count == 3)                  // only 3 owned → 3 slots filled
        #expect(Set(used).count == used.count)    // no duplicates
    }

    @Test func emptyRosterFillsNothing() {
        let r = SquadAutoFill.pick(slots: slots, from: [])
        #expect(r.allSatisfy { $0 == nil })
    }
}
