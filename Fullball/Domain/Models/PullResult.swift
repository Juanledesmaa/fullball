import Foundation

/// The outcome of a single roll from `GachaEngine`. Pure value type.
struct RollOutcome: Sendable, Equatable {
    let card: Card
    let pityAfter: PityState
    /// True when this roll was a hard/soft-pity or natural Icon that
    /// consumed the featured guarantee.
    let wasGuaranteedIcon: Bool
}

/// A roll resolved by the service, including ownership info for the UI.
struct PullResult: Sendable, Identifiable {
    let id = UUID()
    let card: Card
    let isNew: Bool
    let pityAfter: PityState
}
