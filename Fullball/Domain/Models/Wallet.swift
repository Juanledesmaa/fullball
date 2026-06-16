import Foundation
import SwiftData

/// The player's currency balances. Single persisted instance per install.
@Model
final class Wallet {
    var coins: Int
    var gems: Int
    var tickets: Int
    var formTokens: Int

    init(coins: Int = 0, gems: Int = 0, tickets: Int = 0, formTokens: Int = 0) {
        self.coins = coins
        self.gems = gems
        self.tickets = tickets
        self.formTokens = formTokens
    }

    func balance(_ currency: Currency) -> Int {
        switch currency {
        case .coins: return coins
        case .gems: return gems
        case .tickets: return tickets
        case .formTokens: return formTokens
        }
    }

    func credit(_ currency: Currency, _ amount: Int) {
        switch currency {
        case .coins: coins += amount
        case .gems: gems += amount
        case .tickets: tickets += amount
        case .formTokens: formTokens += amount
        }
    }

    /// Returns true and debits if the balance covers `amount`; else false.
    @discardableResult
    func debit(_ currency: Currency, _ amount: Int) -> Bool {
        guard balance(currency) >= amount else { return false }
        credit(currency, -amount)
        return true
    }

    static var starter: Wallet {
        Wallet(coins: 2500, gems: 1600, tickets: 10, formTokens: 0)
    }
}
