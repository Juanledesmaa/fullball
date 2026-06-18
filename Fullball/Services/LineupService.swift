import Foundation
import SwiftData

/// Manages the active matchday lineup: which owned cards are fielded and
/// which one is captain. Persisted via SwiftData.
@MainActor
protocol LineupService: AnyObject {
    var maxFielded: Int { get }
    func fielded() -> [String]
    var captainID: String? { get }
    var count: Int { get }
    func isFielded(_ id: String) -> Bool
    func isCaptain(_ id: String) -> Bool
    /// Toggle a card in/out of the lineup. Returns false if the lineup is
    /// full (and the card wasn't already fielded).
    @discardableResult func toggleField(_ id: String) -> Bool
    func setCaptain(_ id: String?)
}

/// Captain scores double — the multiplier other features read.
enum LineupRules { static let captainMultiplier = 2 }

@MainActor
final class SwiftDataLineupService: LineupService {
    let maxFielded = 5
    private let context: ModelContext
    private let model: Lineup

    init(context: ModelContext, validIDs: Set<String> = []) {
        self.context = context
        let descriptor = FetchDescriptor<Lineup>()
        if let existing = try? context.fetch(descriptor).first {
            self.model = existing
        } else {
            let fresh = Lineup()
            context.insert(fresh)
            self.model = fresh
            try? context.save()
        }
        // Drop fielded ids not in the current catalog (e.g. after the asset/catalog
        // revamp changed card ids) so stale players can't linger in the lineup.
        if !validIDs.isEmpty {
            let before = model.fieldedIDs.count
            model.fieldedIDs.removeAll { !validIDs.contains($0) }
            if let cap = model.captainID, !validIDs.contains(cap) { model.captainID = nil }
            if model.fieldedIDs.count != before { try? context.save() }
        }
    }

    func fielded() -> [String] { model.fieldedIDs }
    var captainID: String? { model.captainID }
    var count: Int { model.fieldedIDs.count }
    func isFielded(_ id: String) -> Bool { model.fieldedIDs.contains(id) }
    func isCaptain(_ id: String) -> Bool { model.captainID == id }

    @discardableResult
    func toggleField(_ id: String) -> Bool {
        if let idx = model.fieldedIDs.firstIndex(of: id) {
            model.fieldedIDs.remove(at: idx)
            if model.captainID == id { model.captainID = nil }
        } else {
            guard model.fieldedIDs.count < maxFielded else { return false }
            model.fieldedIDs.append(id)
            if model.captainID == nil { model.captainID = id }  // first pick auto-captains
        }
        try? context.save()
        return true
    }

    func setCaptain(_ id: String?) {
        if let id, !model.fieldedIDs.contains(id) { return }
        model.captainID = id
        try? context.save()
    }
}
