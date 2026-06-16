import Foundation
import SwiftData

/// Persists per-match results for a slate so entries and outcomes survive
/// relaunch.
@MainActor
protocol MatchProgressStore: AnyObject {
    func records(slateID: String) -> [MatchRecord]
    /// Get-or-create the record for a match in a slate.
    func record(slateID: String, fixtureID: String) -> MatchRecord
    func save()
}

@MainActor
final class SwiftDataMatchStore: MatchProgressStore {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func records(slateID: String) -> [MatchRecord] {
        let descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.slateID == slateID })
        return (try? context.fetch(descriptor)) ?? []
    }

    func record(slateID: String, fixtureID: String) -> MatchRecord {
        let key = "\(slateID)#\(fixtureID)"
        let descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let fresh = MatchRecord(slateID: slateID, fixtureID: fixtureID)
        context.insert(fresh)
        try? context.save()
        return fresh
    }

    func save() { try? context.save() }
}
