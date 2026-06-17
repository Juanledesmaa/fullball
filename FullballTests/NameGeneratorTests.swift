import Testing
@testable import Fullball

struct NameGeneratorTests {
    @Test func deterministicPerId() {
        #expect(NameGenerator.funnyName(for: "ARG-10") == NameGenerator.funnyName(for: "ARG-10"))
    }

    @Test func differentIdsUsuallyDiffer() {
        let a = NameGenerator.funnyName(for: "ARG-10")
        let b = NameGenerator.funnyName(for: "FRA-7")
        #expect(a != b)
    }

    @Test func neverEmptyAndHasTwoParts() {
        for id in ["ARG-10", "BRA-9", "x", "ZZZ-99"] {
            let name = NameGenerator.funnyName(for: id)
            #expect(!name.isEmpty)
            #expect(name.contains(" "))   // at least first + last
        }
    }

    @Test func authoredNameWinsAndEpithetAppends() {
        let icon = Player(id: "P1", displayName: "ARG #10", nationTag: "ARG",
                          shirtNumber: 10, position: .fwd, name: "Raiden",
                          epithet: "The Comet", stats: Stats(pace:90,shooting:90,passing:80,defending:60))
        #expect(icon.funnyName == "Raiden — The Comet")
        let reg = Player(id: "P2", displayName: "BRA #7", nationTag: "BRA",
                         shirtNumber: 7, position: .fwd, name: "Kaito",
                         stats: Stats(pace:80,shooting:80,passing:80,defending:60))
        #expect(reg.funnyName == "Kaito")
    }
}
