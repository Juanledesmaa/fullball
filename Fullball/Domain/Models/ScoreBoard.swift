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

/// Live user score driven by the match feed, persisted via SwiftData and —
/// when signed in — written through to Firestore so points/daily/milestone
/// state survive reinstall and keep the leaderboard entry durable.
@MainActor
@Observable
final class ScoreBoard {
    private let context: ModelContext
    private let model: LiveProgress
    private let client: FirestoreClient?
    private let uid: String?

    init(context: ModelContext, client: FirestoreClient? = nil, uid: String? = nil) {
        self.context = context
        self.client = client
        self.uid = uid
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
        push()
    }

    /// Login reconciliation. Cloud wins; if no cloud doc exists, seed it from local.
    func hydrate() async {
        guard let client, let uid else { return }
        do {
            if let dto = try await client.fetchProgress(uid: uid) {
                dto.apply(to: model)
                try? context.save()
            } else {
                try await client.putProgress(uid: uid, ProgressDTO(model))
            }
        } catch {
            print("Progress hydrate failed: \(error as NSError)")
        }
    }

    /// Fire-and-forget write-through of the whole progress snapshot.
    private func push() {
        guard let client, let uid else { return }
        let dto = ProgressDTO(model)
        Task { do { try await client.putProgress(uid: uid, dto) } catch { print("putProgress failed: \(error)") } }
    }
}
