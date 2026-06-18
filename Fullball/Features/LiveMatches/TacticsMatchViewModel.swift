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

    // MARK: - Per-match slot assignments (1-2-1 futsal formation)

    let slots: [Position] = OffPosition.slots   // [.gk, .def, .mid, .mid, .fwd]
    var assignments: [String?] = Array(repeating: nil, count: 5)   // slotIndex -> cardID

    var assignedIDs: [String] { assignments.compactMap { $0 } }

    func assign(_ id: String, toSlot i: Int) {
        // Remove the card from any slot it already occupies, then place it
        if let prev = assignments.firstIndex(of: id) { assignments[prev] = nil }
        assignments[i] = id
        if captainID == nil || !assignedIDs.contains(captainID!) { captainID = assignedIDs.first }
    }

    func clearSlot(_ i: Int) {
        if assignments[i] == captainID { captainID = nil }
        assignments[i] = nil
        if captainID == nil { captainID = assignedIDs.first }
    }

    var captainID: String? = nil

    func setCaptain(_ id: String) {
        if assignedIDs.contains(id) { captainID = id }
    }

    var canKickOff: Bool { !assignedIDs.isEmpty && canAfford && !alreadyFinished }

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

    // MARK: - Home side assembly (uses slot assignments with off-position penalty)

    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        var inputs: [(id: String, position: Position, stats: Stats)] = []
        for (i, idOpt) in assignments.enumerated() {
            guard let id = idOpt, let oc = owned.first(where: { $0.id == id }) else { continue }
            let withEnergy = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: energy.current(oc.instance))
            let adjusted = OffPosition.adjust(stats: withEnergy, playerPosition: oc.card.player.position, slot: slots[i])
            // Feed slots[i] as the position so the engine's GK/outfield split is correct
            inputs.append((id, slots[i], adjusted))
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: captainID)
    }

    // MARK: - Match flow

    func kickOff() {
        guard phase == .setup,
              !alreadyFinished,
              canAfford,
              !assignedIDs.isEmpty else { return }
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
        if pay.rep > 0  { wallet.credit(.formTokens, pay.rep) }
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

        energy.drainAfterMatch(fieldedIDs: assignedIDs, captainID: captainID, intensity: tactics.intensity)
    }

    // MARK: - Helpers for views

    var opponentName: String { catalog.nationName(fixture.awayTag) }
    var yourFieldedCount: Int { assignedIDs.count }

    /// Match clock label: shows current minute during play, "FULL TIME" at end.
    var minuteLabel: String {
        guard result != nil else { return "" }
        if phase == .fullTime { return "FULL TIME" }
        let minute = Int(Double(minuteIndex) / Double(FutsalRules.possessionCount) * 90)
        return "\(minute)′"
    }

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

    /// Returns the OwnedCard currently in the given slot, or nil if empty.
    func slotPlayer(_ i: Int) -> OwnedCard? {
        guard i < assignments.count, let id = assignments[i] else { return nil }
        return collection.owned().first { $0.id == id }
    }

    /// True if the player assigned to slot i exists and their position differs from the slot's required position.
    func isOffPosition(_ i: Int) -> Bool {
        guard let oc = slotPlayer(i) else { return false }
        return oc.card.player.position != slots[i]
    }

    func myFieldedCards() -> [MatchPlayer] {
        let owned = collection.owned()
        return assignments.enumerated().compactMap { (i, idOpt) in
            guard let id = idOpt, let oc = owned.first(where: { $0.id == id }) else { return nil }
            let e = energy.current(oc.instance)
            let stats = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: e)
            return MatchPlayer(id: oc.id, position: slots[i], stats: stats)
        }
    }

    func catalogCard(_ id: String) -> Card? { catalog.card(id: id) }
    func ownedCard(_ id: String) -> OwnedCard? { collection.owned().first { $0.id == id } }

    var hasTiredPlayers: Bool {
        assignedIDs.contains { energy($0) < EnergyRules.penaltyThreshold }
    }
}
