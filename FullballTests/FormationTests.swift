import Testing
@testable import Fullball

struct FormationTests {
    @Test func shapeRPSDefensiveBeatsAttackingBeatsDiamondBeatsDefensive() {
        #expect(Formation.defensive.edge(against: .attacking) == 1)
        #expect(Formation.attacking.edge(against: .diamond) == 1)
        #expect(Formation.diamond.edge(against: .defensive) == 1)
        #expect(Formation.attacking.edge(against: .defensive) == -1)
        #expect(Formation.diamond.edge(against: .diamond) == 0)
    }

    @Test func allCasesHaveDistinctDisplayNames() {
        let names = Set(Formation.allCases.map(\.displayName))
        #expect(names.count == Formation.allCases.count)
    }
}
