import Foundation

/// A currency grant (any subset). Used by milestones and exchanges.
struct CurrencyGrant: Equatable, Sendable {
    var coins = 0
    var gems = 0
    var tickets = 0
}

// MARK: - Matchday milestones

struct MilestoneTier: Equatable, Sendable {
    let threshold: Int   // career points required
    let gems: Int
    let tickets: Int
    var grant: CurrencyGrant { CurrencyGrant(gems: gems, tickets: tickets) }
}

/// Career-point milestones that fund pulls from live performance. Pure +
/// testable; the service persists how many have been claimed.
enum Milestones {
    static let tiers: [MilestoneTier] = [
        .init(threshold: 500,  gems: 150,  tickets: 1),
        .init(threshold: 1500, gems: 300,  tickets: 2),
        .init(threshold: 3000, gems: 500,  tickets: 3),
        .init(threshold: 5000, gems: 800,  tickets: 4),
        .init(threshold: 8000, gems: 1200, tickets: 5),
    ]

    /// How many tiers a points total has reached.
    static func earnedCount(_ points: Int) -> Int { tiers.filter { points >= $0.threshold }.count }

    /// Tiers earned but not yet claimed.
    static func newlyClaimable(points: Int, claimed: Int) -> [MilestoneTier] {
        let earned = earnedCount(points)
        guard earned > claimed, claimed >= 0, claimed < tiers.count else { return [] }
        return Array(tiers[claimed..<earned])
    }

    /// The next tier the player is working toward, if any.
    static func next(after points: Int) -> MilestoneTier? { tiers.first { points < $0.threshold } }
}

// MARK: - Form Token exchange

/// Exchange rates converting live-earned Form Tokens into pull currency.
/// This is what closes the loop: play live → Form Tokens → more pulls.
enum ExchangeRates {
    static let formPerTicket = 8
    static let formPerGemPack = 40
    static let gemsPerPack = 250

    static func canBuyTicket(form: Int) -> Bool { form >= formPerTicket }
    static func canBuyGemPack(form: Int) -> Bool { form >= formPerGemPack }
}

// MARK: - Agent economy

/// You're an agent: clients earn you a commission (Cash) on performance, and
/// you sign marquee clients on the transfer market.
enum AgentRules {
    /// Cash paid per match point a fielded client earns (your cut).
    static let cashPerPoint = 3

    static func commission(forPoints points: Int) -> Int { max(0, points) * cashPerPoint }
}

/// Transfer-market pricing for signing a specific client outright.
enum TransferRules {
    static func price(rarity: Rarity, overall: Int) -> Int {
        let base: Int
        switch rarity {
        case .icon:   base = 6000
        case .gold:   base = 1200
        case .silver: base = 500
        case .bronze: base = 200
        }
        // Scale a little by overall so standout clients cost more.
        return base + overall * 40
    }
}

// MARK: - Live match rules

/// Rules for paid, fixed-duration live matches.
enum LiveRules {
    static let entryFeeCoins = 200          // cost to enter a match
    static let fullTimeMinute = 90          // match length in game-minutes
    static let realDurationSeconds = 40     // wall-clock length of a match
    static let winBonusTarget = 150         // match points needed for the bonus
    static let winBonusTickets = 1          // bonus paid when target is met

    static var realDuration: Duration { .seconds(realDurationSeconds) }
}

/// Cost to manually refresh the match slate with Gems (premium). Free
/// refreshes still happen every time block; this skips the wait. Escalates
/// per refresh within a block to keep the sink meaningful.
enum RefreshRules {
    static let baseCost = 150
    /// Gems for the next refresh, given how many manual refreshes already
    /// happened this block (0 → 150, 1 → 300, 2 → 450 …).
    static func cost(forCount n: Int) -> Int { baseCost * (n + 1) }
}
