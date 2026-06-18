import Testing
@testable import Fullball

struct OpponentGeneratorTests {
    private let cat = MockCatalogService()
    private func anyTag() -> String { cat.cards.first!.player.nationTag }

    @Test func deterministicForSameSeed() {
        let a = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        let b = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        #expect(a == b)
    }
    @Test func producesFivePlayersWithOneKeeper() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 7)
        #expect(side.players.count == 5)
        #expect(side.goalkeeper != nil)
        #expect(side.outfield.count == 4)
    }
    @Test func dangerManIsHighestShootingOutfielder() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 11)
        let topShooter = side.outfield.max { $0.stats.shooting < $1.stats.shooting }
        #expect(side.dangerManID == topShooter?.id)
    }
    @Test func fallsBackToGlobalPoolWhenNationTooSmall() {
        let side = OpponentGenerator.opponent(awayTag: "ZZZ", cards: cat.cards, seed: 3)
        #expect(side.players.count == 5)
    }
}
