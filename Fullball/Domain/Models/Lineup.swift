import Foundation
import SwiftData

/// The user's active matchday lineup — the cards that actually earn points
/// in live matches, plus a captain who scores double. Single persisted row.
@Model
final class Lineup {
    var fieldedIDs: [String]
    var captainID: String?

    // Tactics — raw primitives so SwiftData can persist them directly.
    // Defaults match Tactics() so existing persisted rows migrate cleanly.
    var formationRaw: String = Formation.diamond.rawValue
    var mentalityRaw: Int = Mentality.balanced.rawValue
    var markerID: String? = nil
    var counterRaw: String? = nil

    init(fieldedIDs: [String] = [], captainID: String? = nil) {
        self.fieldedIDs = fieldedIDs
        self.captainID = captainID
    }
}
