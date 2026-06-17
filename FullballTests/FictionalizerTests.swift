import Testing
import Foundation
@testable import Fullball

struct FictionalizerTests {

    @Test func generatedNamesAreAlwaysFictional() {
        // Feed signals carrying nation/position/rating only — never a name.
        let signals = [
            PlayerSignal(nationTag: "ARG", position: .fwd, rating: 7.9),
            PlayerSignal(nationTag: "ARG", position: .mid, rating: 6.7),
            PlayerSignal(nationTag: "FRA", position: .def, rating: 7.3),
            PlayerSignal(nationTag: "BRA", position: .gk, rating: nil),
        ]
        let cards = Fictionalizer.cards(from: signals)
        let pattern = try! NSRegularExpression(pattern: "^[A-Z]{2,4} #\\d+$")
        for card in cards {
            let name = card.player.displayName
            let range = NSRange(name.startIndex..., in: name)
            #expect(pattern.firstMatch(in: name, range: range) != nil,
                    "displayName must be fictional TAG #num, got \(name)")
        }
    }

    @Test func shirtNumbersIncrementPerNation() {
        let signals = [
            PlayerSignal(nationTag: "ARG", position: .fwd, rating: 7.0),
            PlayerSignal(nationTag: "ARG", position: .fwd, rating: 7.0),
            PlayerSignal(nationTag: "FRA", position: .fwd, rating: 7.0),
        ]
        let cards = Fictionalizer.cards(from: signals)
        #expect(cards[0].id == "ARG-1")
        #expect(cards[1].id == "ARG-2")
        #expect(cards[2].id == "FRA-1")
    }

    @Test func ratingMapsToRarityBands() {
        #expect(Fictionalizer.rarity(forRating: 7.9) == .icon)
        #expect(Fictionalizer.rarity(forRating: 7.3) == .gold)
        #expect(Fictionalizer.rarity(forRating: 7.0) == .gold)
        #expect(Fictionalizer.rarity(forRating: 6.7) == .silver)
        #expect(Fictionalizer.rarity(forRating: 6.0) == .bronze)
        #expect(Fictionalizer.rarity(forRating: nil) == .bronze)
    }
}
