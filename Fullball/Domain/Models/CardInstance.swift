import Foundation
import SwiftData

/// An owned, mutable card. References a catalog `Card` by id. Duplicate
/// pulls accumulate as `copies`, which limit-break consumes for stars.
@Model
final class CardInstance {
    @Attribute(.unique) var cardID: String
    var level: Int
    var stars: Int
    var xp: Int
    var copies: Int          // unconsumed duplicate copies (limit-break fuel)
    var dateAcquired: Date

    init(cardID: String,
         level: Int = 1,
         stars: Int = 0,
         xp: Int = 0,
         copies: Int = 0,
         dateAcquired: Date = .now) {
        self.cardID = cardID
        self.level = level
        self.stars = stars
        self.xp = xp
        self.copies = copies
        self.dateAcquired = dateAcquired
    }
}
