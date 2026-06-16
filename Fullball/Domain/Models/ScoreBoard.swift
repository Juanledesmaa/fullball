import Foundation
import SwiftData

/// Persisted live-match progress (single row per install).
@Model
final class LiveProgress {
    var points: Int
    var formTokensEarned: Int
    var lastDailyClaim: Date?
    var milestonesClaimed: Int = 0
    var slateBlock: String?            // base slate id (day + time block)
    var slateRefreshCount: Int = 0     // manual gem refreshes this block
    init(points: Int = 0, formTokensEarned: Int = 0, lastDailyClaim: Date? = nil,
         milestonesClaimed: Int = 0) {
        self.points = points
        self.formTokensEarned = formTokensEarned
        self.lastDailyClaim = lastDailyClaim
        self.milestonesClaimed = milestonesClaimed
    }
}

/// Live user score driven by the mock match feed, persisted via SwiftData
/// and shared across the Live and Leaderboard tabs.
@MainActor
@Observable
final class ScoreBoard {
    private let context: ModelContext
    private let model: LiveProgress

    init(context: ModelContext) {
        self.context = context
        let descriptor = FetchDescriptor<LiveProgress>()
        if let existing = try? context.fetch(descriptor).first {
            self.model = existing
        } else {
            let fresh = LiveProgress()
            context.insert(fresh)
            self.model = fresh
            try? context.save()
        }
    }

    var points: Int { model.points }
    var formTokensEarned: Int { model.formTokensEarned }

    func award(points: Int, formTokens: Int) {
        model.points += points
        model.formTokensEarned += formTokens
        try? context.save()
    }
}
