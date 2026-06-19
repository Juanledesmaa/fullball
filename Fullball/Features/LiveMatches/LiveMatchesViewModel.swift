import SwiftUI

/// One line in a match's event feed (kept for potential future use / auto path).
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
    private let milestones: any MilestoneService
    private let store: any MatchProgressStore
    private let slateService: MatchSlateService
    private(set) var slateID: String
    private let auth: any AuthService
    private let navigator: Navigator
    private let energyService: any EnergyService

    var matches: [MatchState]
    var sessionPoints = 0
    var sessionCash = 0
    var milestoneToast: String?
    var matchResult: String?
    private var tasks: [String: Task<Void, Never>] = [:]

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
        self.milestones = container.milestones
        self.store = container.matchStore
        self.slateService = container.slate
        self.slateID = container.slate.slateID
        self.auth = container.auth
        self.navigator = container.navigator
        self.energyService = container.energy
        self.matches = container.slate.fixtures
            .filter { $0.status == .live }
            .map { MatchState(fixture: $0) }
        restore()
    }

    // MARK: slate refresh (premium)

    var refreshCost: Int { slateService.nextRefreshCost }
    var refreshCount: Int { slateService.refreshCount }
    var canRefresh: Bool { liveMatchCount == 0 && slateService.canAffordRefresh }

    func refreshSlate() {
        guard liveMatchCount == 0 else { return }
        guard slateService.refresh() else {
            matchResult = "Not enough Gems to refresh"; scheduleClear(\.matchResult); return
        }
        stop()
        slateID = slateService.slateID
        matches = slateService.fixtures
            .filter { $0.status == .live }
            .map { MatchState(fixture: $0) }
        restore()
        matchResult = "Fresh slate loaded"
        scheduleClear(\.matchResult)
    }

    /// Reapply persisted records so entries/results survive relaunch.
    func restore() {
        for rec in store.records(slateID: slateID) {
            guard let idx = matches.firstIndex(where: { $0.id == rec.fixtureID }) else { continue }
            matches[idx].pointsEarned = rec.pointsEarned
            matches[idx].formEarned = rec.formEarned
            matches[idx].home = rec.home
            matches[idx].away = rec.away
            matches[idx].wonBonus = rec.wonBonus
            matches[idx].phase = .fullTime
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

    func stop() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
    }

    var liveMatchCount: Int { tasks.count }

    // MARK: milestones

    var nextMilestone: MilestoneTier? { milestones.next(points: careerPoints) }
    var milestoneProgress: Double {
        guard let next = nextMilestone else { return 1 }
        let prev = Milestones.tiers.last { careerPoints >= $0.threshold }?.threshold ?? 0
        let span = next.threshold - prev
        guard span > 0 else { return 0 }
        return min(1, max(0, Double(careerPoints - prev) / Double(span)))
    }

    func energy(forCardID id: String) -> Int {
        guard let inst = collection.instance(forCardID: id) else { return EnergyRules.maxEnergy }
        return energyService.current(inst)
    }

    func nationName(_ tag: String) -> String { catalog.nationName(tag) }

    private func scheduleClear(_ keyPath: ReferenceWritableKeyPath<LiveMatchesViewModel, String?>) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.5))
            self?[keyPath: keyPath] = nil
        }
    }
}
