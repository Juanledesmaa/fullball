import SwiftUI

/// Turn live-earned Form Tokens into pull currency. This is what lets live
/// play fund more pulls — closing the core loop.
struct FormExchangeSheet: View {
    let container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var version = 0

    private var form: Int { _ = version; return container.wallet.balance(.formTokens) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    Text("Rep is earned only by fielding clients in live matches. Trade it for scouting passes and transfer funds.")
                        .font(WC.ui(12)).foregroundStyle(WC.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    offer(title: "1 Scout", cost: ExchangeRates.formPerTicket,
                          tint: WC.coral, symbol: Currency.tickets.symbol,
                          enabled: ExchangeRates.canBuyTicket(form: form)) {
                        container.exchange.buyTicket(); version += 1
                    }
                    offer(title: "\(ExchangeRates.gemsPerPack) Gems", cost: ExchangeRates.formPerGemPack,
                          tint: Currency.gems.tint, symbol: Currency.gems.symbol,
                          enabled: ExchangeRates.canBuyGemPack(form: form)) {
                        container.exchange.buyGemPack(); version += 1
                    }
                }
                .padding(16)
            }
            .background(ScreenBackground())
            .navigationTitle("Rep Exchange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(WC.display(13)).tint(WC.coral)
                }
            }
        }
    }

    private var balanceCard: some View {
        PanelCard(borderColor: WC.go, borderWidth: 2) {
            HStack(spacing: 10) {
                Image(systemName: Currency.formTokens.symbol).font(.system(size: 24))
                    .foregroundStyle(WC.go)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(form)").font(WC.display(28)).foregroundStyle(WC.inkText)
                    Text("REP").font(WC.display(9)).tracking(0.8).foregroundStyle(WC.sub)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private func offer(title: String, cost: Int, tint: Color, symbol: String,
                       enabled: Bool, action: @escaping () -> Void) -> some View {
        PanelCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(WC.display(16)).foregroundStyle(WC.inkText)
                    CurrencyCost(currency: .formTokens, amount: cost)
                }
                Spacer()
                Button(action: action) {
                    Text("TRADE").font(WC.display(12)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(enabled ? WC.go : WC.faint))
                }
                .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.5)
            }
            .padding(12)
        }
    }
}
