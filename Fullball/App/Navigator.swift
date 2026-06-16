import SwiftUI

/// Shared tab selection so any screen can route the user (e.g. an empty
/// Collection nudging toward the Packs tab).
@MainActor
@Observable
final class Navigator {
    enum Tab: Int { case packs = 0, market = 1, collection = 2, live = 3, leaderboard = 4 }
    var tab: Int

    init() {
        let i = UserDefaults.standard.integer(forKey: "startTab")
        self.tab = (0...4).contains(i) ? i : 0
    }

    func go(_ t: Tab) { tab = t.rawValue }
}
