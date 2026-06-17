import Foundation
import Testing
import SwiftData
@testable import Fullball

@MainActor
struct CloudDTOTests {
    private let container = try! ModelContainer(
        for: Schema([Wallet.self, CardInstance.self, LiveProgress.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    @Test func walletRoundTrips() {
        let w = Wallet(coins: 2500, gems: 1600, tickets: 10, formTokens: 5)
        let dto = WalletDTO(w)
        #expect(dto == WalletDTO(coins: 2500, gems: 1600, tickets: 10, formTokens: 5))
        let w2 = Wallet()
        dto.apply(to: w2)
        #expect(w2.coins == 2500 && w2.gems == 1600 && w2.tickets == 10 && w2.formTokens == 5)
    }

    @Test func cardInstanceRoundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let inst = CardInstance(cardID: "ARG-10", level: 4, stars: 2, xp: 30, copies: 3, dateAcquired: date)
        let dto = CardInstanceDTO(inst)
        #expect(dto.cardID == "ARG-10")
        #expect(dto.level == 4 && dto.stars == 2 && dto.xp == 30 && dto.copies == 3)
        #expect(dto.dateAcquired == date)
        let rebuilt = dto.makeInstance()
        #expect(rebuilt.cardID == "ARG-10" && rebuilt.level == 4 && rebuilt.stars == 2
                && rebuilt.xp == 30 && rebuilt.copies == 3 && rebuilt.dateAcquired == date)
    }

    @Test func pityRoundTrips() {
        let dto = PityDTO(bannerID: "featured", state: PityState(pullsSinceIcon: 7, guaranteeFeatured: true))
        #expect(dto.pullsSinceIcon == 7 && dto.guaranteeFeatured == true)
        #expect(dto.state == PityState(pullsSinceIcon: 7, guaranteeFeatured: true))
    }

    @Test func progressRoundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let p = LiveProgress(points: 1200, formTokensEarned: 40,
                             lastDailyClaim: date, milestonesClaimed: 2)
        p.slateBlock = "20260617-1"
        p.slateRefreshCount = 3
        let dto = ProgressDTO(p)
        #expect(dto.points == 1200 && dto.formTokensEarned == 40)
        #expect(dto.lastDailyClaim == date && dto.milestonesClaimed == 2)
        #expect(dto.slateBlock == "20260617-1" && dto.slateRefreshCount == 3)
        let p2 = LiveProgress()
        dto.apply(to: p2)
        #expect(p2.points == 1200 && p2.formTokensEarned == 40 && p2.milestonesClaimed == 2)
        #expect(p2.lastDailyClaim == date && p2.slateBlock == "20260617-1" && p2.slateRefreshCount == 3)
    }
}
