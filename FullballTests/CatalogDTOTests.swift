import Testing
import Foundation
@testable import Fullball

struct CatalogDTOTests {
    @Test func catalogDTOMapsToData() throws {
        let json = """
        {"nations":[{"tag":"ARG","name":"Argentina"}],
         "cards":[{"id":"P1","player":{"id":"P1","displayName":"ARG #1","nationTag":"ARG",
           "shirtNumber":1,"position":"FWD","name":"Kaito",
           "stats":{"pace":80,"shooting":80,"passing":70,"defending":50}},"rarity":"gold"}]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(CatalogDTO.self, from: json)
        let data = dto.toData(banners: [], fixtures: [])
        #expect(data.cards.count == 1)
        #expect(data.cards[0].player.funnyName == "Kaito")
        #expect(data.cards[0].rarity == .gold)
        #expect(data.nations.first?.tag == "ARG")
    }
}
