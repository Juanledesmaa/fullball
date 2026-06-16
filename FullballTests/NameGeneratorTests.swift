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
}
