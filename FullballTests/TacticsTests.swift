import Testing
import Foundation
@testable import Fullball

struct TacticsTests {
    @Test func defaultsAreBalanced() {
        let t = Tactics()
        #expect(t.intensity == .balanced)
        #expect(t.focus == .balanced)
    }
    @Test func intensityDrainFactorOrders() {
        #expect(Intensity.conservative.drainFactor < Intensity.balanced.drainFactor)
        #expect(Intensity.balanced.drainFactor < Intensity.aggressive.drainFactor)
    }
    @Test func everyOptionHasImpactText() {
        #expect(Intensity.allCases.allSatisfy { !$0.impact.isEmpty })
        #expect(Focus.allCases.allSatisfy { !$0.impact.isEmpty })
    }
    @Test func codableRoundTrips() throws {
        let t = Tactics(intensity: .aggressive, focus: .attack)
        let back = try JSONDecoder().decode(Tactics.self, from: JSONEncoder().encode(t))
        #expect(back == t)
    }
}
