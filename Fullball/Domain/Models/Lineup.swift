import Foundation
import SwiftData

/// The user's active matchday lineup — the cards that actually earn points
/// in live matches, plus a captain who scores double. Single persisted row.
@Model
final class Lineup {
    var fieldedIDs: [String]
    var captainID: String?

    init(fieldedIDs: [String] = [], captainID: String? = nil) {
        self.fieldedIDs = fieldedIDs
        self.captainID = captainID
    }
}
