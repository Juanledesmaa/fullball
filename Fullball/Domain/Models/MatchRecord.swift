import Foundation
import SwiftData

/// Persisted state of one entered match within a slate. Lets entries and
/// results survive relaunch.
@Model
final class MatchRecord {
    @Attribute(.unique) var key: String   // "<slateID>#<fixtureID>"
    var slateID: String
    var fixtureID: String
    var statusRaw: String                 // "entered" | "finished"
    var pointsEarned: Int
    var formEarned: Int
    var home: Int
    var away: Int
    var wonBonus: Bool

    init(slateID: String, fixtureID: String, statusRaw: String = "entered",
         pointsEarned: Int = 0, formEarned: Int = 0, home: Int = 0, away: Int = 0,
         wonBonus: Bool = false) {
        self.key = "\(slateID)#\(fixtureID)"
        self.slateID = slateID
        self.fixtureID = fixtureID
        self.statusRaw = statusRaw
        self.pointsEarned = pointsEarned
        self.formEarned = formEarned
        self.home = home
        self.away = away
        self.wonBonus = wonBonus
    }

    var finished: Bool { statusRaw == "finished" }
}
