import Foundation
import Observation

@MainActor @Observable
final class TacticsMatchViewModel {

    // MARK: - Phase

    enum Phase: Equatable { case setup, playing, fullTime }

    // MARK: - Dependencies

    let fixture: Fixture
    private let catalog: any CatalogService
    private let collection: any CollectionService
    private let lineup: any LineupService
    private let wallet: any WalletService
    private let score: ScoreBoard
    private let milestones: any MilestoneService
    private let store: any MatchProgressStore
    private let slateID: String
    private let energy: any EnergyService

    // MARK: - Scouting / setup state

    let opponent: MatchSide

    /// Mirrors `LineupService.tactics`; writing through persists to LineupService.
    var tactics: Tactics {
        didSet { lineup.setTactics(tactics) }
    }

    // MARK: - Playback state

    var phase: Phase = .setup
    var minuteIndex = 0
    var homeGoals = 0
    var awayGoals = 0
    var lastEvent: PossessionEvent?
    private(set) var result: MatchResult?
    private(set) var payout: FutsalReward.Payout?
    var awardedTiers: [MilestoneTier] = []

    // MARK: - Guards

    let entryFee = LiveRules.entryFeeCoins

    var canAfford: Bool { wallet.balance(.coins) >= entryFee }

    var alreadyFinished: Bool {
        store.record(slateID: slateID, fixtureID: fixture.id).statusRaw == "finished"
    }

    // MARK: - Deterministic seed (shared: same fixture same for all devices)

    var seed: UInt64 {
        DeviceSeed.sharedSeed(for: slateID) &+ UInt64(bitPattern: Int64(fixture.id.hashValue))
    }

    // MARK: - Init

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        self.fixture = fixture
        self.catalog = container.catalog
        self.collection = container.collection
        self.lineup = container.lineup
        self.wallet = container.wallet
        self.score = container.score
        self.milestones = container.milestones
        self.store = container.matchStore
        self.slateID = slateID
        self.energy = container.energy

        let fixtureSeed = DeviceSeed.sharedSeed(for: slateID)
            &+ UInt64(bitPattern: Int64(fixture.id.hashValue))
        self.opponent = OpponentGenerator.opponent(
            awayTag: fixture.awayTag,
            cards: container.catalog.cards,
            seed: fixtureSeed
        )
        self.tactics = container.lineup.tactics
    }

    // MARK: - Home side assembly

    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        let inputs: [(id: String, position: Position, stats: Stats)] = lineup.fielded().compactMap { id in
            guard let oc = owned.first(where: { $0.id == id }) else { return nil }
            let e = energy.current(oc.instance)
            let stats = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: e)
            return (id, oc.card.player.position, stats)
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: lineup.captainID)
    }

    // MARK: - Match flow

    func kickOff() {
        guard phase == .setup,
              !alreadyFinished,
              canAfford,
              !lineup.fielded().isEmpty else { return }
        wallet.debit(.coins, entryFee)
        let res = FutsalEngine.play(home: buildHomeSide(), away: opponent, seed: seed)
        result = res
        phase = .playing
        minuteIndex = 0
    }

    /// Advance one possession event. Returns `true` while there are more events
    /// to step through, `false` when the match is settled (caller stops the timer).
    @discardableResult
    func step() -> Bool {
        guard let res = result, phase == .playing else { return false }
        guard minuteIndex < res.events.count else { settle(); return false }
        let e = res.events[minuteIndex]
        lastEvent = e
        if e.outcome == .goal {
            if e.attackingHome { homeGoals += 1 } else { awayGoals += 1 }
        }
        minuteIndex += 1
        if minuteIndex >= res.events.count { settle(); return false }
        return true
    }

    // MARK: - Settlement (private — called once, idempotent via phase guard)

    private func settle() {
        guard phase == .playing, let res = result else { return }
        phase = .fullTime

        let pay = FutsalReward.from(
            contributions: res.homeContributions,
            captainID: lineup.captainID
        )
        payout = pay

        // Award career points + form tokens.
        score.award(points: pay.points, formTokens: pay.rep)

        // Coin commission.
        if pay.cash > 0 { wallet.credit(.coins, pay.cash) }

        // Win-bonus ticket.
        if pay.wonBonus { wallet.credit(.tickets, LiveRules.winBonusTickets) }

        wallet.save()

        // Persist match outcome.
        let rec = store.record(slateID: slateID, fixtureID: fixture.id)
        rec.statusRaw = "finished"
        rec.pointsEarned = pay.points
        rec.formEarned = pay.rep
        rec.home = res.homeGoals
        rec.away = res.awayGoals
        rec.wonBonus = pay.wonBonus
        store.save()

        // Claim any newly-unlocked milestones.
        awardedTiers = milestones.claim(points: score.points)

        energy.drainAfterMatch(fieldedIDs: lineup.fielded(), captainID: lineup.captainID, intensity: tactics.intensity)
    }

    // MARK: - Scouting helpers (for views)

    var opponentName: String { catalog.nationName(fixture.awayTag) }
    var yourFieldedCount: Int { lineup.fielded().count }

    func myFieldedCards() -> [OwnedCard] {
        let ids = Set(lineup.fielded())
        return collection.owned().filter { ids.contains($0.id) }
    }

    func catalogCard(_ id: String) -> Card? { catalog.card(id: id) }
}
