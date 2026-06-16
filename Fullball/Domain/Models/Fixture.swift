import Foundation

enum MatchStatus: String, Codable, Sendable {
    case upcoming, live, final
}

/// A scripted live-match event. Awards points + Form Tokens to holders of
/// the named catalog player when it fires.
struct ScriptedEvent: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let minute: Int        // match minute the event fires at
    let playerID: String   // catalog Player.id that performed
    let kind: EventKind
    let points: Int
    let formTokens: Int

    enum EventKind: String, Codable, Sendable {
        case goal, assist, cleanSheet, save, yellowCard
        var label: String {
            switch self {
            case .goal: return "Goal"
            case .assist: return "Assist"
            case .cleanSheet: return "Clean sheet"
            case .save: return "Big save"
            case .yellowCard: return "Yellow card"
            }
        }
        var symbol: String {
            switch self {
            case .goal: return "soccerball"
            case .assist: return "arrow.up.forward"
            case .cleanSheet: return "lock.shield"
            case .save: return "hand.raised.fill"
            case .yellowCard: return "rectangle.portrait.fill"
            }
        }
    }
}

/// A mock in-progress fixture with a scripted event feed.
struct Fixture: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let homeTag: String
    let awayTag: String
    let group: String
    let venue: String
    var status: MatchStatus
    let scriptedEvents: [ScriptedEvent]
}
