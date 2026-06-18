import SwiftUI

struct CardDetailView: View {
    @State private var vm: CardDetailViewModel

    init(container: AppContainer, cardID: String) {
        _vm = State(initialValue: CardDetailViewModel(container: container, cardID: cardID))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                portraitHero
                VStack(spacing: 16) {
                    statsPanel
                    progressionPanel
                    limitBreakPanel
                    if vm.owned { energyPanel }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(ScreenBackground())
        .ignoresSafeArea(edges: .top)
        .navigationTitle(vm.card.funnyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var portraitHero: some View {
        ZStack(alignment: .bottom) {
            CardPortraitFull(card: vm.card)
                .frame(maxWidth: .infinity)
                .background(vm.card.rarity.color.opacity(0.18))
            // legibility gradient
            LinearGradient(colors: [.clear, .black.opacity(0.05), .black.opacity(0.8)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .bottom) {
                    RarityTag(rarity: vm.card.rarity)
                    Spacer()
                    VStack(spacing: -2) {
                        Text("\(vm.effectiveStats.overall)").font(WC.display(30)).foregroundStyle(.white)
                        Text("OVR").font(WC.display(9)).tracking(1).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Text(vm.card.funnyName).font(WC.display(24)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
                HStack(spacing: 8) {
                    NationBadge(code: vm.card.player.nationTag, width: 26)
                    Text("#\(vm.card.player.shirtNumber) · \(vm.card.player.position.displayName.uppercased())")
                        .font(WC.display(10)).tracking(0.5).foregroundStyle(.white.opacity(0.85))
                }
                StarRow(stars: vm.stars, cap: vm.card.rarity.starCap, size: 15)
            }
            .padding(16).padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(vm.card.rarity.color).frame(height: 4)
        }
    }

    private var statsPanel: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Attributes")
                statBar("PACE", vm.effectiveStats.pace)
                statBar("SHOOTING", vm.effectiveStats.shooting)
                statBar("PASSING", vm.effectiveStats.passing)
                statBar("DEFENDING", vm.effectiveStats.defending)
            }
            .padding(14)
        }
    }

    private func statBar(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 10) {
            Text(label).font(WC.display(10)).tracking(0.4).foregroundStyle(WC.sub)
                .frame(width: 78, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WC.fill)
                    Capsule().fill(vm.card.rarity.color)
                        .frame(width: max(4, geo.size.width * Double(min(value, 99)) / 99))
                }
            }
            .frame(height: 7)
            Text("\(value)").font(WC.display(13)).foregroundStyle(WC.inkText)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private var progressionPanel: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Level", right: "\(vm.level) / \(vm.levelCap)")
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WC.fill)
                        Capsule().fill(WC.go).frame(width: max(4, geo.size.width * vm.xpProgress))
                    }
                }
                .frame(height: 8)
                Text(vm.atLevelCap ? "Max level for this star tier — limit-break to raise the cap."
                                   : "\(vm.xp) / \(vm.xpToNext) XP to next level")
                    .font(WC.ui(10.5)).foregroundStyle(WC.faint)
                actionButton(title: "TRAIN", subtitle: "\(vm.trainCost) Coins · +\(UpgradeRules.xpPerTrain) XP",
                             enabled: vm.canTrain, filled: true) { vm.train() }
            }
            .padding(14)
        }
    }

    private var limitBreakPanel: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Limit break", right: "★ \(vm.stars) / \(vm.card.rarity.starCap)")
                StarRow(stars: vm.stars, cap: vm.card.rarity.starCap, size: 16)
                HStack {
                    Image(systemName: "rectangle.on.rectangle.angled").foregroundStyle(WC.sub)
                    Text("\(vm.copies) duplicate copies").font(WC.ui(12)).foregroundStyle(WC.sub)
                    Spacer()
                    if !vm.maxedStars {
                        Text("Need \(vm.copiesForNextStar)").font(WC.display(11)).foregroundStyle(WC.coral)
                    }
                }
                Text(vm.maxedStars ? "Fully limit-broken — max stars reached."
                                   : "Each star adds +\(UpgradeRules.statBumpPerStar) to every stat and raises the level cap.")
                    .font(WC.ui(10.5)).foregroundStyle(WC.faint)
                actionButton(title: "LIMIT BREAK", subtitle: vm.maxedStars ? "Maxed" : "Consume \(vm.copiesForNextStar) copies",
                             enabled: vm.canLimitBreak, filled: false) { vm.limitBreak() }
            }
            .padding(14)
        }
    }

    private var energyPanel: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Energy")
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WC.fill)
                        Capsule()
                            .fill(vm.currentEnergy >= EnergyRules.maxEnergy ? WC.go : WC.coral)
                            .frame(width: max(4, geo.size.width * Double(vm.currentEnergy) / Double(EnergyRules.maxEnergy)))
                    }
                }
                .frame(height: 8)
                Text("Restores ~4 energy per hour (full in ~24h). Refill instantly with Gems.")
                    .font(WC.ui(11)).foregroundStyle(WC.sub)
                HStack {
                    Text("Energy \(vm.currentEnergy) / \(EnergyRules.maxEnergy)")
                        .font(WC.ui(13)).foregroundStyle(WC.sub)
                    Spacer()
                    Button { vm.refillEnergy() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill").font(.system(size: 12))
                            Text("Refill")
                            CurrencyCost(currency: .gems, amount: vm.refillCost)
                        }
                        .font(WC.ui(13))
                    }
                    .disabled(vm.refillCost == 0 || !vm.canAffordRefill)
                    .opacity((vm.refillCost == 0 || !vm.canAffordRefill) ? 0.5 : 1)
                }
            }
            .padding(14)
        }
    }

    private func actionButton(title: String, subtitle: String, enabled: Bool,
                              filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(WC.display(14)).tracking(0.5)
                Text(subtitle).font(WC.display(9.5)).opacity(0.85)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .foregroundStyle(filled ? .white : WC.inkText)
            .background(RoundedRectangle(cornerRadius: 12).fill(filled ? WC.coral : WC.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(filled ? .clear : WC.inkText, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

#Preview {
    NavigationStack {
        CardDetailView(container: .preview(), cardID: "ARG-10")
    }
}
