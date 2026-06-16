import SwiftUI

struct MarketView: View {
    @State private var vm: MarketViewModel

    init(container: AppContainer) {
        _vm = State(initialValue: MarketViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(kicker: "Sign marquee clients · pay Cash", title: "Market")
            ScrollView {
                VStack(spacing: 12) {
                    Text("Scouting is a gamble. The transfer market is a sure thing — pay Cash to sign a specific client outright. Shortlist refreshes daily.")
                        .font(WC.ui(12)).foregroundStyle(WC.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if vm.listings.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.listings) { listingCard($0) }
                    }
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
        .overlay(alignment: .top) { toast }
    }

    @ViewBuilder private var toast: some View {
        if let msg = vm.toast {
            HStack(spacing: 8) {
                Image(systemName: "signature").foregroundStyle(WC.go)
                Text(msg).font(WC.display(11)).foregroundStyle(.white).lineLimit(1)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(WC.ink))
            .overlay(Capsule().strokeBorder(WC.go, lineWidth: 1.5))
            .padding(.top, 6).padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: vm.toast)
        }
    }

    private func listingCard(_ l: TransferListing) -> some View {
        let card = l.card
        let owned = vm.owned(l)
        let afford = vm.canAfford(l)
        return PanelCard(borderColor: card.rarity.color, borderWidth: 2) {
            HStack(spacing: 12) {
                AvatarView(card: card).frame(width: 64, height: 64)
                    .background(card.rarity.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(card.rarity.color, lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.funnyName).font(WC.display(14)).foregroundStyle(WC.inkText)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        RarityTag(rarity: card.rarity)
                        NationBadge(code: card.player.nationTag, width: 20)
                        Text("OVR \(card.player.stats.overall)").font(WC.display(10)).foregroundStyle(WC.sub)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: Currency.coins.symbol).font(.system(size: 11)).foregroundStyle(WC.go)
                        Text("\(l.price)").font(WC.display(15)).foregroundStyle(WC.inkText)
                    }
                }
                Spacer()
                signButton(l, owned: owned, afford: afford)
            }
            .padding(12)
        }
    }

    private func signButton(_ l: TransferListing, owned: Bool, afford: Bool) -> some View {
        Button { vm.sign(l) } label: {
            Text(owned ? "RE-SIGN" : "SIGN").font(WC.display(12)).foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(afford ? WC.go : WC.faint))
        }
        .buttonStyle(.plain)
        .disabled(!afford)
        .opacity(afford ? 1 : 0.5)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(WC.go)
            Text("Shortlist cleared").font(WC.display(15)).foregroundStyle(WC.inkText)
            Text("You've signed everyone available. New marquee clients list tomorrow.")
                .font(WC.ui(12)).foregroundStyle(WC.sub).multilineTextAlignment(.center).padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }
}

#Preview {
    MarketView(container: .preview())
}
