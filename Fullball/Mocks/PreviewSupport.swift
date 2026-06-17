import SwiftUI
import SwiftData

/// In-memory catalog for SwiftUI Previews — no bundle dependency.
struct MockCatalogService: CatalogService {
    let cards: [Card]
    let banners: [Banner]
    let fixtures: [Fixture]
    let nations: [Nation]

    init() {
        func p(_ id: String, _ tag: String, _ num: Int, _ pos: Position, _ s: Stats) -> Player {
            Player(id: id, displayName: "\(tag) #\(num)", nationTag: tag,
                   shirtNumber: num, position: pos, stats: s)
        }
        func c(_ id: String, _ tag: String, _ num: Int, _ pos: Position, _ r: Rarity, _ s: Stats) -> Card {
            Card(id: id, player: p(id, tag, num, pos, s), rarity: r, artRef: pos.symbol)
        }
        let st = Stats(pace: 80, shooting: 78, passing: 75, defending: 55)
        cards = [
            c("ARG-10", "ARG", 10, .fwd, .icon, Stats(pace: 88, shooting: 92, passing: 90, defending: 45)),
            c("FRA-10", "FRA", 10, .fwd, .icon, Stats(pace: 95, shooting: 90, passing: 82, defending: 40)),
            c("BRA-9", "BRA", 9, .fwd, .gold, st),
            c("MEX-9", "MEX", 9, .fwd, .gold, st),
            c("NED-10", "NED", 10, .fwd, .gold, st),
            c("ENG-8", "ENG", 8, .mid, .silver, Stats(pace: 70, shooting: 68, passing: 80, defending: 66)),
            c("GER-5", "GER", 5, .mid, .silver, Stats(pace: 66, shooting: 60, passing: 78, defending: 70)),
            c("ESP-6", "ESP", 6, .mid, .gold, Stats(pace: 74, shooting: 70, passing: 88, defending: 72)),
            c("USA-7", "USA", 7, .def, .bronze, Stats(pace: 64, shooting: 40, passing: 60, defending: 72)),
            c("JPN-11", "JPN", 11, .fwd, .bronze, Stats(pace: 75, shooting: 64, passing: 62, defending: 44)),
            c("ITA-1", "ITA", 1, .gk, .bronze, Stats(pace: 50, shooting: 30, passing: 58, defending: 80)),
        ]
        nations = [Nation(tag: "ARG", name: "Argentina"), Nation(tag: "FRA", name: "France"),
                   Nation(tag: "BRA", name: "Brazil"), Nation(tag: "MEX", name: "Mexico"),
                   Nation(tag: "NED", name: "Netherlands"), Nation(tag: "ENG", name: "England")]
        banners = [
            Banner(id: "standard", title: "Global Scout", subtitle: "Always-on standard pool",
                   type: .standard, featuredCardIDs: [],
                   singleCost: .ticket(1), multiCost: .gems(1500)),
            Banner(id: "featured", title: "Today's Match", subtitle: "ARG #10 & FRA #10 rate-up",
                   type: .featured, featuredCardIDs: ["ARG-10", "FRA-10"],
                   singleCost: .ticket(1), multiCost: .gems(1500)),
        ]
        fixtures = [
            Fixture(id: "f1", homeTag: "MEX", awayTag: "NED", group: "Group A",
                    venue: "Estadio Azteca · Mexico City", status: .live, scriptedEvents: [
                        ScriptedEvent(id: "f1e1", minute: 12, playerID: "MEX-9", kind: .goal, points: 120, formTokens: 2),
                        ScriptedEvent(id: "f1e2", minute: 24, playerID: "NED-10", kind: .assist, points: 60, formTokens: 1),
                    ]),
            Fixture(id: "f2", homeTag: "ARG", awayTag: "BRA", group: "Group C",
                    venue: "MetLife Stadium · New Jersey", status: .live, scriptedEvents: [
                        ScriptedEvent(id: "f2e1", minute: 8, playerID: "ARG-10", kind: .goal, points: 150, formTokens: 3),
                        ScriptedEvent(id: "f2e2", minute: 31, playerID: "BRA-9", kind: .goal, points: 150, formTokens: 3),
                    ]),
        ]
    }
}

extension AppContainer {
    /// An in-memory container for previews, optionally pre-seeded with a
    /// few owned cards so collection/detail screens have content.
    @MainActor
    static func preview(ownedCardIDs: [String] = ["ARG-10", "BRA-9", "ENG-8", "USA-7"]) -> AppContainer {
        let container = try! ModelContainer(
            for: AppContainer.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let app = AppContainer(context: context, catalog: MockCatalogService())
        for id in ownedCardIDs { app.collection.acquire(cardID: id) }
        // Give one card some duplicates so limit-break is demoable.
        if let inst = app.collection.instance(forCardID: "ARG-10") {
            inst.copies = 4
            app.wallet.save()
        }
        // Field a few cards (ARG-10 captain) so the Live tab has a lineup.
        for id in ownedCardIDs.prefix(3) { app.lineup.toggleField(id) }
        return app
    }
}
