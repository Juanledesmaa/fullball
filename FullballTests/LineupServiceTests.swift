import Testing
import SwiftData
@testable import Fullball

@MainActor
struct LineupServiceTests {
    private func makeService() -> SwiftDataLineupService {
        let container = try! ModelContainer(
            for: Schema([Lineup.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return SwiftDataLineupService(context: container.mainContext)
    }

    @Test func fieldingAddsAndFirstPickAutoCaptains() {
        let s = makeService()
        s.toggleField("ARG-10")
        #expect(s.isFielded("ARG-10"))
        #expect(s.isCaptain("ARG-10"))   // first pick becomes captain
        #expect(s.count == 1)
    }

    @Test func togglingOffRemovesAndClearsCaptain() {
        let s = makeService()
        s.toggleField("ARG-10")
        s.toggleField("ARG-10")
        #expect(!s.isFielded("ARG-10"))
        #expect(s.captainID == nil)
        #expect(s.count == 0)
    }

    @Test func cannotExceedMaxFielded() {
        let s = makeService()
        for i in 0..<(s.maxFielded + 3) { s.toggleField("C-\(i)") }
        #expect(s.count == s.maxFielded)
        let overflow = s.toggleField("C-999")
        #expect(overflow == false)
        #expect(!s.isFielded("C-999"))
    }

    @Test func captainMustBeFielded() {
        let s = makeService()
        s.setCaptain("NOT-FIELDED")
        #expect(s.captainID == nil)
        s.toggleField("BRA-9")
        s.setCaptain("BRA-9")
        #expect(s.isCaptain("BRA-9"))
    }

    @Test func captainMultiplierIsTwo() {
        #expect(LineupRules.captainMultiplier == 2)
    }
}
