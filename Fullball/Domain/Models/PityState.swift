import Foundation
import SwiftData

/// Pure, value-type pity state for one banner. Fed to `GachaEngine`.
struct PityState: Sendable, Equatable {
    /// Pulls accumulated on this banner since the last Icon.
    var pullsSinceIcon: Int = 0
    /// Set when a guaranteed Icon resolved off-banner — the *next*
    /// guaranteed Icon must be the featured card (the 50/50 rule).
    var guaranteeFeatured: Bool = false
}

/// Persisted per-banner pity. Thin SwiftData mirror of `PityState`.
@Model
final class BannerPity {
    @Attribute(.unique) var bannerID: String
    var pullsSinceIcon: Int
    var guaranteeFeatured: Bool

    init(bannerID: String, pullsSinceIcon: Int = 0, guaranteeFeatured: Bool = false) {
        self.bannerID = bannerID
        self.pullsSinceIcon = pullsSinceIcon
        self.guaranteeFeatured = guaranteeFeatured
    }

    var state: PityState {
        PityState(pullsSinceIcon: pullsSinceIcon, guaranteeFeatured: guaranteeFeatured)
    }

    func apply(_ s: PityState) {
        pullsSinceIcon = s.pullsSinceIcon
        guaranteeFeatured = s.guaranteeFeatured
    }
}
