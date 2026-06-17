import Testing
@testable import Fullball

struct CatalogBuildTests {
    let cat = BundledCatalogService()

    @Test func has61CardsAllFourTiers() {
        #expect(cat.cards.count == 61)
        let tiers = Set(cat.cards.map(\.rarity))
        #expect(tiers == Set([.bronze, .silver, .gold, .icon]))
    }

    @Test func everyCardHasAuthoredName() {
        for c in cat.cards { #expect(!(c.player.name ?? "").isEmpty) }
    }

    @Test func iconsAreTen() {
        let icons = cat.cards.filter { $0.rarity == .icon }
        #expect(icons.count == 10)
        for i in icons { #expect(!(i.player.epithet ?? "").isEmpty) }
    }

    @Test func nationsCoverAllCardTags() {
        let tags = Set(cat.nations.map(\.tag))
        for c in cat.cards { #expect(tags.contains(c.player.nationTag)) }
    }

    @Test func featuredBannerCardsExist() {
        guard let featured = cat.featuredBanner else { return }
        let ids = Set(cat.cards.map(\.id))
        for fid in featured.featuredCardIDs { #expect(ids.contains(fid)) }
    }
}
