import Foundation

/// Codable mirrors of the persisted models, used as the Firestore wire format.
/// Pure value types so the mapping is unit-testable. FirebaseFirestore
/// encodes/decodes these via its built-in Codable support.

struct WalletDTO: Codable, Equatable {
    var coins: Int
    var gems: Int
    var tickets: Int
    var formTokens: Int

    init(coins: Int, gems: Int, tickets: Int, formTokens: Int) {
        self.coins = coins; self.gems = gems; self.tickets = tickets; self.formTokens = formTokens
    }

    @MainActor init(_ w: Wallet) {
        self.init(coins: w.coins, gems: w.gems, tickets: w.tickets, formTokens: w.formTokens)
    }

    @MainActor func apply(to w: Wallet) {
        w.coins = coins; w.gems = gems; w.tickets = tickets; w.formTokens = formTokens
    }
}

struct CardInstanceDTO: Codable, Equatable {
    var cardID: String
    var level: Int
    var stars: Int
    var xp: Int
    var copies: Int
    var dateAcquired: Date

    init(cardID: String, level: Int, stars: Int, xp: Int, copies: Int, dateAcquired: Date) {
        self.cardID = cardID; self.level = level; self.stars = stars
        self.xp = xp; self.copies = copies; self.dateAcquired = dateAcquired
    }

    @MainActor init(_ inst: CardInstance) {
        self.init(cardID: inst.cardID, level: inst.level, stars: inst.stars,
                  xp: inst.xp, copies: inst.copies, dateAcquired: inst.dateAcquired)
    }

    @MainActor func makeInstance() -> CardInstance {
        CardInstance(cardID: cardID, level: level, stars: stars,
                     xp: xp, copies: copies, dateAcquired: dateAcquired)
    }
}

struct PityDTO: Codable, Equatable {
    var bannerID: String
    var pullsSinceIcon: Int
    var guaranteeFeatured: Bool

    init(bannerID: String, pullsSinceIcon: Int, guaranteeFeatured: Bool) {
        self.bannerID = bannerID
        self.pullsSinceIcon = pullsSinceIcon
        self.guaranteeFeatured = guaranteeFeatured
    }

    init(bannerID: String, state: PityState) {
        self.init(bannerID: bannerID,
                  pullsSinceIcon: state.pullsSinceIcon,
                  guaranteeFeatured: state.guaranteeFeatured)
    }

    var state: PityState {
        PityState(pullsSinceIcon: pullsSinceIcon, guaranteeFeatured: guaranteeFeatured)
    }
}
