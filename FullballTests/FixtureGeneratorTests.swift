import Testing
@testable import Fullball

struct FixtureGeneratorTests {
    private let cat = MockCatalogService()

    @Test func sameSeedIsDeterministic() {
        let a = FixtureGenerator.slate(seed: 42, nations: cat.nations, cards: cat.cards, count: 3)
        let b = FixtureGenerator.slate(seed: 42, nations: cat.nations, cards: cat.cards, count: 3)
        #expect(a == b)
        #expect(!a.isEmpty)
    }

    @Test func differentSeedDiffersSlate() {
        let a = FixtureGenerator.slate(seed: 42, nations: cat.nations, cards: cat.cards, count: 3)
        let c = FixtureGenerator.slate(seed: 99, nations: cat.nations, cards: cat.cards, count: 3)
        #expect(a != c)
    }

    @Test func eventsReferenceRealCardsAndDistinctTeams() {
        let slate = FixtureGenerator.slate(seed: 7, nations: cat.nations, cards: cat.cards, count: 3)
        let ids = Set(cat.cards.map(\.id))
        for fx in slate {
            #expect(fx.homeTag != fx.awayTag)
            #expect(fx.status == .live)
            for e in fx.scriptedEvents { #expect(ids.contains(e.playerID)) }
        }
    }

    @Test func respectsCountAndNationSupply() {
        // 6 mock nations → at most 3 pairings.
        let slate = FixtureGenerator.slate(seed: 1, nations: cat.nations, cards: cat.cards, count: 10)
        #expect(slate.count <= 3)
    }
}
