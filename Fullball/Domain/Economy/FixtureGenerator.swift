import Foundation

/// Procedurally generates a slate of live fixtures from a seed. Pure and
/// deterministic: the same seed always yields the same matches, so a slate
/// is stable for a given device + time block but varies across them.
enum FixtureGenerator {
    static let stages = ["Group A", "Group B", "Group C", "Group D",
                         "Round of 16", "Quarter-final", "Semi-final", "Final"]
    static let venues = ["Lusail Stadium", "MetLife Stadium", "SoFi Stadium",
                         "Estadio Azteca", "Al Bayt Stadium", "Rose Bowl", "Education City"]

    static func slate(seed: UInt64, nations: [Nation], cards: [Card], count: Int = 5) -> [Fixture] {
        var rng = SeededRandomProvider(seed: seed)
        let cardsByNation = Dictionary(grouping: cards, by: { $0.player.nationTag })
        // Only use nations that actually have cards (so fielded players can play).
        var pool = nations.map(\.tag).filter { !(cardsByNation[$0]?.isEmpty ?? true) }
        pool = shuffle(pool, &rng)

        var fixtures: [Fixture] = []
        var idx = 0
        while fixtures.count < count && idx + 1 < pool.count {
            let home = pool[idx], away = pool[idx + 1]
            idx += 2
            let stage = stages[rng.nextInt(stages.count)]
            let venue = venues[rng.nextInt(venues.count)]
            let events = generateEvents(home: home, away: away,
                                        cardsByNation: cardsByNation,
                                        index: fixtures.count, rng: &rng)
            fixtures.append(Fixture(id: "m\(fixtures.count)", homeTag: home, awayTag: away,
                                    group: stage, venue: venue, status: .live, scriptedEvents: events))
        }
        return fixtures
    }

    private static func generateEvents<R: RandomProvider>(
        home: String, away: String, cardsByNation: [String: [Card]],
        index: Int, rng: inout R
    ) -> [ScriptedEvent] {
        let teamCards = (cardsByNation[home] ?? []) + (cardsByNation[away] ?? [])
        guard !teamCards.isEmpty else { return [] }
        let n = 3 + rng.nextInt(4)   // 3–6 events
        var events: [ScriptedEvent] = []
        for k in 0..<n {
            let card = teamCards[rng.nextInt(teamCards.count)]
            let minute = 1 + rng.nextInt(90)
            let (kind, points, form) = pickKind(&rng)
            events.append(ScriptedEvent(id: "m\(index)e\(k)", minute: minute,
                                        playerID: card.id, kind: kind,
                                        points: points, formTokens: form))
        }
        return events.sorted { $0.minute < $1.minute }
    }

    private static func pickKind<R: RandomProvider>(_ rng: inout R)
        -> (ScriptedEvent.EventKind, Int, Int) {
        switch rng.nextInt(100) {
        case 0..<30:  return (.goal, 120 + rng.nextInt(40), 2 + rng.nextInt(2))
        case 30..<55: return (.assist, 50 + rng.nextInt(30), 1)
        case 55..<70: return (.save, 30 + rng.nextInt(20), 1)
        case 70..<85: return (.cleanSheet, 70 + rng.nextInt(30), 2)
        default:      return (.yellowCard, -10, 0)
        }
    }

    static func shuffle<T, R: RandomProvider>(_ array: [T], _ rng: inout R) -> [T] {
        var a = array
        var i = a.count - 1
        while i > 0 {
            let j = rng.nextInt(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }
}
