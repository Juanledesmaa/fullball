import SwiftUI

/// One line in a match's event feed.
struct LiveFeedItem: Identifiable {
    let id = UUID()
    let minute: Int
    let playerName: String
    let nationTag: String
    let kind: ScriptedEvent.EventKind
    let points: Int
    let formTokens: Int
    let fielded: Bool
    let isCaptain: Bool
}

/// State of one match in the live lobby.
struct MatchState: Identifiable {
    enum Phase { case lobby, live, fullTime }
    let fixture: Fixture
    var phase: Phase = .lobby
    var minute: Int = 0
    var home: Int = 0
    var away: Int = 0
    var pointsEarned: Int = 0
    var formEarned: Int = 0
    var wonBonus = false
    var id: String { fixture.id }
}

@MainActor
@Observable
final class LiveMatchesViewModel {
    private let live: any LiveMatchService
    private let collection: any CollectionService
    private let wallet: any WalletService
    private let catalog: any CatalogService
    private let score: ScoreBoard
    private let lineup: any LineupService
    private let milestones: any MilestoneService
    private let store: any MatchProgressStore
    private let slateService: MatchSlateService
    private var slateID: String
    private let auth: any AuthService
    private let navigator: Navigator

    var matches: [MatchState]
    var feed: [LiveFeedItem] = []
    var sessionPoints = 0
    var sessionCash = 0
    var milestoneToast: String?
    var matchResult: String?
    private var tasks: [String: Task<Void, Never>] = [:]   // one per live match

    let entryFee = LiveRules.entryFeeCoins

    var careerPoints: Int { score.points }
    var formTokensEarned: Int { score.formTokensEarned }
    var coins: Int { wallet.balance(.coins) }

    init(container: AppContainer) {
        self.live = container.live
        self.collection = container.collection
        self.wallet = container.wallet
        self.catalog = container.catalog
        self.score = container.score
        self.lineup = container.lineup
        self.milestones = container.milestones
        self.store = container.matchStore
        self.slateService = container.slate
        self.slateID = container.slate.slateID
        self.auth = container.auth
        self.navigator = container.navigator
        // Procedurally-generated slate; only live matches are enterable.
        self.matches = container.slate.fixtures
            .filter { $0.status == .live }
            .map { MatchState(fixture: $0) }
        restore()
    }

    // MARK: slate refresh (premium)

    var refreshCost: Int { slateService.nextRefreshCost }
    var refreshCount: Int { slateService.refreshCount }
    /// Only refresh between matches so no entry fee is wasted.
    var canRefresh: Bool { liveMatchCount == 0 && slateService.canAffordRefresh }

    func refreshSlate() {
        guard liveMatchCount == 0 else { return }
        guard slateService.refresh() else {
            matchResult = "Not enough Gems to refresh"; scheduleClear(\.matchResult); return
        }
        stop()
        slateID = slateService.slateID
        feed.removeAll()
        matches = slateService.fixtures
            .filter { $0.status == .live }
            .map { MatchState(fixture: $0) }
        restore()
        matchResult = "Fresh slate loaded"
        scheduleClear(\.matchResult)
    }

    /// Reapply persisted records so entries/results survive relaunch.
    private func restore() {
        for rec in store.records(slateID: slateID) {
            guard let idx = matches.firstIndex(where: { $0.id == rec.fixtureID }) else { continue }
            matches[idx].pointsEarned = rec.pointsEarned
            matches[idx].formEarned = rec.formEarned
            matches[idx].home = rec.home
            matches[idx].away = rec.away
            matches[idx].wonBonus = rec.wonBonus
            matches[idx].phase = .fullTime
            // Entered but interrupted (app closed mid-match) → finalize now.
            if !rec.finished {
                if !rec.wonBonus && matches[idx].pointsEarned >= LiveRules.winBonusTarget {
                    wallet.credit(.tickets, LiveRules.winBonusTickets)
                    matches[idx].wonBonus = true
                    rec.wonBonus = true
                }
                rec.statusRaw = "finished"
                store.save()
            }
        }
    }

    private func persist(_ idx: Int) {
        let m = matches[idx]
        let rec = store.record(slateID: slateID, fixtureID: m.id)
        rec.pointsEarned = m.pointsEarned
        rec.formEarned = m.formEarned
        rec.home = m.home
        rec.away = m.away
        rec.wonBonus = m.wonBonus
        rec.statusRaw = (m.phase == .fullTime) ? "finished" : "entered"
        store.save()
    }

    // MARK: lineup-derived

    func fieldedCards() -> [OwnedCard] {
        let owned = collection.owned()
        let set = Set(lineup.fielded())
        return owned.filter { set.contains($0.id) }
            .sorted { lineup.isCaptain($0.id) && !lineup.isCaptain($1.id) }
    }
    var fieldedCount: Int { lineup.count }
    var maxFielded: Int { lineup.maxFielded }

    func isNationLive(_ tag: String) -> Bool {
        matches.contains { ($0.fixture.homeTag == tag || $0.fixture.awayTag == tag) }
    }

    /// Your fielded clients who actually play in a given fixture (i.e. can
    /// earn you a commission there). Captain first.
    func fieldedPlayers(in fixture: Fixture) -> [OwnedCard] {
        fieldedCards().filter { $0.card.player.nationTag == fixture.homeTag
                             || $0.card.player.nationTag == fixture.awayTag }
    }

    func yourPlayers(in fixture: Fixture) -> Int { fieldedPlayers(in: fixture).count }

    var liveMatchCount: Int { tasks.count }

    // MARK: entry + play

    /// Multiple matches can run at once — entry just needs the fee.
    func canEnter(_ match: MatchState) -> Bool {
        match.phase == .lobby && coins >= entryFee
    }

    func enter(_ match: MatchState) {
        guard canEnter(match) else { return }
        guard wallet.debit(.coins, entryFee) else { return }
        guard let idx = matches.firstIndex(where: { $0.id == match.id }) else { return }
        matches[idx].phase = .live
        persist(idx)
        let fixture = match.fixture
        tasks[fixture.id] = Task { [weak self] in
            guard let stream = self?.live.play(fixture, realDuration: LiveRules.realDuration) else { return }
            for await tick in stream { self?.handle(tick, fixtureID: fixture.id) }
        }
    }

    func stop() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }

    private func handle(_ tick: MatchTick, fixtureID: String) {
        guard let idx = matches.firstIndex(where: { $0.id == fixtureID }) else { return }
        matches[idx].minute = tick.minute

        if let event = tick.event {
            let card = catalog.card(id: event.playerID)
            let fielded = lineup.isFielded(event.playerID)
            let captain = lineup.isCaptain(event.playerID)
            let multiplier = captain ? LineupRules.captainMultiplier : 1
            let pts = fielded ? event.points * multiplier : 0
            let form = fielded ? event.formTokens : 0

            // running score
            if event.kind == .goal, let tag = card?.player.nationTag {
                if tag == matches[idx].fixture.homeTag { matches[idx].home += 1 }
                else if tag == matches[idx].fixture.awayTag { matches[idx].away += 1 }
            }

            if fielded {
                if form > 0 { wallet.credit(.formTokens, form) }
                let commission = AgentRules.commission(forPoints: pts)
                if commission > 0 { wallet.credit(.coins, commission); sessionCash += commission }
                score.award(points: pts, formTokens: form)
                sessionPoints += pts
                matches[idx].pointsEarned += pts
                matches[idx].formEarned += form
                grantMilestones()
            }

            feed.insert(LiveFeedItem(
                minute: event.minute,
                playerName: card?.funnyName ?? event.playerID,
                nationTag: card?.player.nationTag ?? "?",
                kind: event.kind, points: pts, formTokens: form,
                fielded: fielded, isCaptain: captain), at: 0)
            if feed.count > 24 { feed.removeLast() }
            persist(idx)
        }

        if tick.isFullTime { settle(idx) }
    }

    private func settle(_ idx: Int) {
        matches[idx].phase = .fullTime
        tasks[matches[idx].id] = nil
        let earned = matches[idx].pointsEarned
        if earned >= LiveRules.winBonusTarget {
            wallet.credit(.tickets, LiveRules.winBonusTickets)
            matches[idx].wonBonus = true
            matchResult = "Full time! \(earned) pts · +\(LiveRules.winBonusTickets) Ticket bonus"
        } else {
            matchResult = "Full time! \(earned) pts earned"
        }
        persist(idx)
        scheduleClear(\.matchResult)
    }

    // MARK: milestones

    var nextMilestone: MilestoneTier? { milestones.next(points: careerPoints) }
    var milestoneProgress: Double {
        guard let next = nextMilestone else { return 1 }
        let prev = Milestones.tiers.last { careerPoints >= $0.threshold }?.threshold ?? 0
        let span = next.threshold - prev
        guard span > 0 else { return 0 }
        return min(1, max(0, Double(careerPoints - prev) / Double(span)))
    }

    private func grantMilestones() {
        let granted = milestones.claim(points: careerPoints)
        guard !granted.isEmpty else { return }
        // First milestone is the hook moment for the one-time "Link Apple ID" prompt.
        if LinkPromptPolicy.shouldPrompt(isAnonymous: auth.currentUser?.isAnonymous ?? false,
                                         alreadyPrompted: UserDefaults.standard.bool(forKey: "didPromptLink"),
                                         firstMilestoneReached: true) {
            navigator.linkPromptPending = true
        }
        let gems = granted.reduce(0) { $0 + $1.gems }
        let tickets = granted.reduce(0) { $0 + $1.tickets }
        var msg = "Milestone! +\(gems) Gems"
        if tickets > 0 { msg += " · +\(tickets) Tickets" }
        milestoneToast = msg
        scheduleClear(\.milestoneToast)
    }

    private func scheduleClear(_ keyPath: ReferenceWritableKeyPath<LiveMatchesViewModel, String?>) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            self?[keyPath: keyPath] = nil
        }
    }

    func nationName(_ tag: String) -> String { catalog.nationName(tag) }
}
