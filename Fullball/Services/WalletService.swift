import Foundation
import SwiftData

/// Owns the persisted `Wallet` and per-banner pity. Main-actor bound
/// because it touches the SwiftData context.
@MainActor
protocol WalletService: AnyObject {
    var wallet: Wallet { get }
    func balance(_ currency: Currency) -> Int
    func credit(_ currency: Currency, _ amount: Int)
    @discardableResult func debit(_ currency: Currency, _ amount: Int) -> Bool
    func pity(for bannerID: String) -> PityState
    func setPity(_ state: PityState, for bannerID: String)
    func save()
}

@MainActor
final class SwiftDataWalletService: WalletService {
    private let context: ModelContext
    let wallet: Wallet

    init(context: ModelContext) {
        self.context = context
        // Fetch the single wallet or seed a starter one.
        let descriptor = FetchDescriptor<Wallet>()
        if let existing = try? context.fetch(descriptor).first {
            self.wallet = existing
        } else {
            let starter = Wallet.starter
            context.insert(starter)
            self.wallet = starter
            try? context.save()
        }
    }

    func balance(_ currency: Currency) -> Int { wallet.balance(currency) }

    func credit(_ currency: Currency, _ amount: Int) {
        wallet.credit(currency, amount)
        save()
    }

    @discardableResult
    func debit(_ currency: Currency, _ amount: Int) -> Bool {
        let ok = wallet.debit(currency, amount)
        if ok { save() }
        return ok
    }

    func pity(for bannerID: String) -> PityState {
        pityModel(for: bannerID).state
    }

    func setPity(_ state: PityState, for bannerID: String) {
        pityModel(for: bannerID).apply(state)
        save()
    }

    private func pityModel(for bannerID: String) -> BannerPity {
        let descriptor = FetchDescriptor<BannerPity>(
            predicate: #Predicate { $0.bannerID == bannerID })
        if let existing = try? context.fetch(descriptor).first { return existing }
        let model = BannerPity(bannerID: bannerID)
        context.insert(model)
        return model
    }

    func save() { try? context.save() }
}
