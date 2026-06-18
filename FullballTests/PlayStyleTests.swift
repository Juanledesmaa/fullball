import Testing
@testable import Fullball

struct PlayStyleTests {
    @Test func derivesFromDominantStat() {
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 10, passing: 90, defending: 10)) == .technical)
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 10, passing: 10, defending: 90)) == .physical)
        #expect(PlayStyle.from(Stats(pace: 90, shooting: 10, passing: 10, defending: 10)) == .pace)
    }

    @Test func tiesResolveTechnicalThenPhysicalThenPace() {
        #expect(PlayStyle.from(Stats(pace: 50, shooting: 50, passing: 50, defending: 50)) == .technical)
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 0, passing: 50, defending: 50)) == .technical)
        #expect(PlayStyle.from(Stats(pace: 50, shooting: 0, passing: 10, defending: 50)) == .physical)
    }

    @Test func rpsEdgeIsPaceBeatsPhysicalBeatsTechnicalBeatsPace() {
        #expect(PlayStyle.pace.edge(against: .physical) == 1)
        #expect(PlayStyle.physical.edge(against: .technical) == 1)
        #expect(PlayStyle.technical.edge(against: .pace) == 1)
        #expect(PlayStyle.physical.edge(against: .pace) == -1)
        #expect(PlayStyle.technical.edge(against: .physical) == -1)
        #expect(PlayStyle.pace.edge(against: .technical) == -1)
        #expect(PlayStyle.technical.edge(against: .technical) == 0)
    }
}
