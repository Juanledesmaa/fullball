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
    private let wallet: any WalletService
    private let score: ScoreBoard
    private let milestones: any MilestoneService
    private let store: any MatchProgressStore
    private let slateID: String
    private let energy: any EnergyService

    // MARK: - Scouting / setup state

    let opponent: MatchSide

    var tactics = Tactics()

    // MARK: - Per-match player selection (not from LineupService)

    var selected: [String] = []       // chosen card ids, max 5
    var captainID: String? = nil
    let maxPlayers = 5

    func toggle(_ id: String) {
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
            if captainID == id { captainID = selected.first }
        } else if selected.count < maxPlayers {
            selected.append(id)
            if captainID == nil { captainID = id }
        }
    }

    func setCaptain(_ id: String) {
        if selected.contains(id) { captainID = id }
    }

    var canKickOff: Bool { !selected.isEmpty && canAfford && !alreadyFinished }

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

    // MARK: - Deterministic seed

    var seed: UInt64 {
        DeviceSeed.sharedSeed(for: slateID) &+ UInt64(bitPattern: Int64(fixture.id.hashValue))
    }

    // MARK: - Init

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        self.fixture = fixture
        self.catalog = container.catalog
        self.collection = container.collection
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
    }

    // MARK: - Home side assembly (uses per-match selection)

    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        let inputs: [(id: String, position: Position, stats: Stats)] = selected.compactMap { id in
            guard let oc = owned.first(where: { $0.id == id }) else { return nil }
            let e = energy.current(oc.instance)
            let stats = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: e)
            return (id, oc.card.player.position, stats)
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: captainID)
    }

    // MARK: - Match flow

    func kickOff() {
        guard phase == .setup,
              !alreadyFinished,
              canAfford,
              !selected.isEmpty else { return }
        wallet.debit(.coins, entryFee)
        let res = FutsalEngine.play(home: buildHomeSide(), away: opponent, seed: seed)
        result = res
        phase = .playing
        minuteIndex = 0
    }

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

    // MARK: - Settlement

    private func settle() {
        guard phase == .playing, let res = result else { return }
        phase = .fullTime

        let pay = FutsalReward.from(
            contributions: res.homeContributions,
            captainID: captainID
        )
        payout = pay

        score.award(points: pay.points, formTokens: pay.rep)
        if pay.cash > 0 { wallet.credit(.coins, pay.cash) }
        if pay.wonBonus { wallet.credit(.tickets, LiveRules.winBonusTickets) }
        wallet.save()

        let rec = store.record(slateID: slateID, fixtureID: fixture.id)
        rec.statusRaw = "finished"
        rec.pointsEarned = pay.points
        rec.formEarned = pay.rep
        rec.home = res.homeGoals
        rec.away = res.awayGoals
        rec.wonBonus = pay.wonBonus
        store.save()

        awardedTiers = milestones.claim(points: score.points)

        energy.drainAfterMatch(fieldedIDs: selected, captainID: captainID, intensity: tactics.intensity)
    }

    // MARK: - Helpers for views

    var opponentName: String { catalog.nationName(fixture.awayTag) }
    var yourFieldedCount: Int { selected.count }

    /// All owned cards sorted by overall desc, then energy desc for selection.
    func ownedForSelection() -> [OwnedCard] {
        collection.owned().sorted {
            let a = $0.effectiveStats.overall; let b = $1.effectiveStats.overall
            if a != b { return a > b }
            return energy($0.id) > energy($1.id)
        }
    }

    func energy(_ id: String) -> Int {
        guard let inst = collection.instance(forCardID: id) else { return EnergyRules.maxEnergy }
        return energy.current(inst)
    }

    func myFieldedCards() -> [MatchPlayer] {
        let owned = collection.owned()
        return selected.compactMap { id in
            guard let oc = owned.first(where: { $0.id == id }) else { return nil }
            let e = energy.current(oc.instance)
            let stats = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: e)
            return MatchPlayer(id: oc.id, position: oc.card.player.position, stats: stats)
        }
    }

    func catalogCard(_ id: String) -> Card? { catalog.card(id: id) }
    func ownedCard(_ id: String) -> OwnedCard? { collection.owned().first { $0.id == id } }

    var hasTiredPlayers: Bool {
        selected.contains { energy($0) < EnergyRules.penaltyThreshold }
    }
}
