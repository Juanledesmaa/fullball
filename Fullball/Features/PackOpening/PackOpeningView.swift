import SwiftUI

struct PackOpeningView: View {
    let container: AppContainer
    @State private var vm: PackOpeningViewModel
    @State private var showOdds = false
    @State private var showExchange = false

    init(container: AppContainer) {
        self.container = container
        _vm = State(initialValue: PackOpeningViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(kicker: "Scout unknown talent", title: "Scout") {
                Button { showOdds = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                        Text("ODDS").font(WC.display(11)).tracking(0.5)
                    }
                    .foregroundStyle(WC.coral)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(WC.coral, lineWidth: 1.5))
                }
            }
            ScrollView {
                VStack(spacing: 16) {
                    if vm.dailyAvailable { dailyDrop }
                    formExchangeRow
                    bannerSelector
                    if !vm.featuredCards().isEmpty { featuredPreview }
                    pityBar
                    pullButtons
                    Spacer(minLength: 8)
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
        .fullScreenCover(isPresented: $vm.showReveal) {
            PackRevealView(results: vm.revealResults) { vm.showReveal = false }
        }
        .sheet(isPresented: $showOdds) { OddsSheet().presentationDetents([.large]) }
        .sheet(isPresented: $showExchange) { FormExchangeSheet(container: container) }
        .alert("Daily Drop", isPresented: Binding(
            get: { vm.claimMessage != nil },
            set: { if !$0 { vm.claimMessage = nil } })) {
            Button("Nice", role: .cancel) { vm.claimMessage = nil }
        } message: { Text(vm.claimMessage ?? "") }
        .alert("Can't pull", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } })) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
    }

    private var dailyDrop: some View {
        PanelCard(borderColor: WC.go, borderWidth: 2) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(WC.go.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: "gift.fill").font(.system(size: 22)).foregroundStyle(WC.go)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAILY DROP").font(WC.display(11)).tracking(0.8).foregroundStyle(WC.go)
                    Text("+3 Scouts · +600 Cash").font(WC.ui(11)).foregroundStyle(WC.sub)
                }
                Spacer()
                Button { vm.claimDaily() } label: {
                    Text("CLAIM").font(WC.display(12)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(Capsule().fill(WC.go))
                }.buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    private var formExchangeRow: some View {
        Button { showExchange = true } label: {
            PanelCard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(WC.go.opacity(0.15)).frame(width: 46, height: 46)
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 20)).foregroundStyle(WC.go)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REP EXCHANGE").font(WC.display(11)).tracking(0.6).foregroundStyle(WC.go)
                        Text("Turn match Rep into Scouts & Gems").font(WC.ui(11)).foregroundStyle(WC.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(WC.faint)
                }
                .padding(12)
            }
        }.buttonStyle(.plain)
    }

    private var bannerSelector: some View {
        VStack(spacing: 10) {
            ForEach(vm.banners) { banner in
                Button { vm.selectedBannerID = banner.id } label: {
                    bannerRow(banner)
                }.buttonStyle(.plain)
            }
        }
    }

    private func bannerRow(_ banner: Banner) -> some View {
        let selected = banner.id == vm.selectedBannerID
        return PanelCard(borderColor: selected ? WC.coral : WC.lineColor,
                         borderWidth: selected ? 2 : 1.5) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(banner.type == .featured ? WC.coralSoft : WC.fill)
                        .frame(width: 52, height: 52)
                    Image(systemName: banner.type == .featured ? "star.circle.fill" : "globe")
                        .font(.system(size: 24))
                        .foregroundStyle(banner.type == .featured ? WC.coral : WC.sub)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(banner.type == .featured ? "FEATURED" : "STANDARD")
                        .font(WC.display(9)).tracking(0.8)
                        .foregroundStyle(banner.type == .featured ? WC.coral : WC.faint)
                    Text(banner.title).font(WC.display(16)).foregroundStyle(WC.inkText)
                    Text(banner.subtitle).font(WC.ui(11)).foregroundStyle(WC.sub).lineLimit(1)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? WC.coral : WC.faint)
            }
            .padding(12)
        }
    }

    private var featuredPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Rate-up Icons", right: "50/50")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.featuredCards()) { card in
                        VStack(spacing: 6) {
                            CardArt(card: card)
                                .frame(width: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(card.rarity.color, lineWidth: 1.5))
                            Text(card.funnyName).font(WC.display(10))
                                .foregroundStyle(WC.inkText).lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }.padding(.horizontal, 2)
            }
        }
    }

    private var pityBar: some View {
        let progress = Double(vm.pullsSinceIcon) / Double(GachaEngine.hardPity)
        return PanelCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PITY · GUARANTEED ICON").font(WC.display(10)).tracking(0.6)
                        .foregroundStyle(WC.sub)
                    Spacer()
                    Text("\(vm.pullsToGuarantee) to go").font(WC.display(11))
                        .foregroundStyle(WC.coral)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WC.fill)
                        Capsule().fill(WC.coral)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                Text("\(vm.pullsSinceIcon) / \(GachaEngine.hardPity) pulls").font(WC.ui(10))
                    .foregroundStyle(WC.faint)
            }
            .padding(13)
        }
    }

    private var pullButtons: some View {
        HStack(spacing: 10) {
            pullButton(multi: false, title: "PULL ×1", filled: true)
            pullButton(multi: true, title: "PULL ×10", filled: false)
        }
    }

    private func pullButton(multi: Bool, title: String, filled: Bool) -> some View {
        let affordable = vm.canAfford(multi: multi)
        let pullCost = multi ? vm.selectedBanner.multiCost : vm.selectedBanner.singleCost
        return Button {
            vm.pull(multi: multi)
        } label: {
            VStack(spacing: 3) {
                Text(title).font(WC.display(15)).tracking(0.5)
                CurrencyCost(currency: pullCost.currency, amount: pullCost.amount)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(filled ? .white : WC.inkText)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(filled ? WC.coral : WC.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(filled ? .clear : WC.inkText, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .opacity(affordable ? 1 : 0.4)
        .disabled(!affordable)
    }
}

#Preview {
    PackOpeningView(container: .preview())
}
