import Testing
import Foundation
@testable import Fullball

struct TacticsTests {
    @Test func mentalityRawValuesSpanDefendToAttack() {
        #expect(Mentality.parkBus.rawValue == -2)
        #expect(Mentality.balanced.rawValue == 0)
        #expect(Mentality.allOut.rawValue == 2)
    }

    @Test func tacticsHasBalancedDefaults() {
        let t = Tactics()
        #expect(t.formation == .diamond)
        #expect(t.mentality == .balanced)
        #expect(t.markerID == nil)
        #expect(t.counter == nil)
    }

    @Test func tacticsIsCodableRoundTrips() throws {
        let t = Tactics(formation: .attacking, mentality: .attack, markerID: "c1", counter: .pace)
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(Tactics.self, from: data)
        #expect(back == t)
    }
}
