import SwiftUI

/// Persistent currency strip. Observes the `@Model` wallet directly, so
/// balances update live as the loop spends/earns.
struct WalletBar: View {
    let wallet: Wallet
    var onBuyGems: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            pill(.coins, wallet.coins)
            pill(.gems, wallet.gems, buyable: true)
            pill(.tickets, wallet.tickets)
            pill(.formTokens, wallet.formTokens)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(WC.cardBG)
        .overlay(Rectangle().frame(height: 1.5).foregroundStyle(WC.lineColor), alignment: .bottom)
    }

    private func pill(_ currency: Currency, _ value: Int, buyable: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: currency.symbol).font(.system(size: 11))
                .foregroundStyle(currency.tint)
            Text(compact(value)).font(WC.display(12)).foregroundStyle(WC.inkText)
                .lineLimit(1).minimumScaleFactor(0.7)
            if buyable {
                Button { onBuyGems?() } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 13))
                        .foregroundStyle(WC.coral)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(WC.fill))
        .frame(maxWidth: .infinity)
    }

    private func compact(_ n: Int) -> String {
        if n >= 10_000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }
}
