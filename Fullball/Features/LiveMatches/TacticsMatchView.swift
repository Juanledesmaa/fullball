import SwiftUI

struct TacticsMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TacticsMatchViewModel

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        _vm = State(initialValue: TacticsMatchViewModel(fixture: fixture, container: container, slateID: slateID))
    }

    var body: some View {
        ZStack {
            WC.screenBG.ignoresSafeArea()
            switch vm.phase {
            case .setup: setup
            case .playing, .fullTime: FutsalPitchView(vm: vm, onClose: { dismiss() })
            }
        }
    }

    // MARK: - Setup screen

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("MATCH SETUP").font(WC.display(20)).foregroundStyle(WC.inkText)
                    Spacer()
                    Button("Close") { dismiss() }.foregroundStyle(WC.sub)
                }

                // Scouting
                scouting

                // Player selection
                playerSelection

                // Tactics
                tacticRow("INTENSITY", Intensity.allCases, vm.tactics.intensity,
                          \.displayName, \.impact) { vm.tactics.intensity = $0 }
                tacticRow("FOCUS", Focus.allCases, vm.tactics.focus,
                          \.displayName, \.impact) { vm.tactics.focus = $0 }

                // Kick off
                kickOff
            }
            .padding(20)
        }
    }

    // MARK: - Scouting

    private var scouting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OPPONENT").font(WC.ui(12)).foregroundStyle(WC.sub)
            Text(vm.opponentName).font(WC.display(22)).foregroundStyle(WC.inkText)
            Text("\(vm.opponent.tactics.intensity.displayName) · \(vm.opponent.tactics.focus.displayName)")
                .font(WC.ui(13)).foregroundStyle(WC.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(WC.cardBG).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Player selection strip

    private var playerSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR SQUAD").font(WC.ui(12)).foregroundStyle(WC.sub)
                Spacer()
                Text("Selected \(vm.selected.count)/\(vm.maxPlayers)")
                    .font(WC.display(11))
                    .foregroundStyle(vm.selected.isEmpty ? WC.coral : WC.go)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.ownedForSelection()) { owned in
                        selectionTile(owned)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func selectionTile(_ owned: OwnedCard) -> some View {
        let isSelected = vm.selected.contains(owned.id)
        let isCaptain = vm.captainID == owned.id
        let e = vm.energy(owned.id)
        let ePct = Double(e) / Double(EnergyRules.maxEnergy)
        let selectionIndex = vm.selected.firstIndex(of: owned.id)

        return Button {
            vm.toggle(owned.id)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topLeading) {
                    AvatarView(card: owned.card)
                        .frame(width: 58, height: 87)
                        .background(owned.card.rarity.color.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    isCaptain ? WC.gold :
                                    isSelected ? owned.card.rarity.color : WC.lineColor,
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )
                    // Selection order badge
                    if let idx = selectionIndex {
                        Text("\(idx + 1)")
                            .font(WC.display(9))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Circle().fill(isSelected ? WC.coral : WC.ink))
                            .offset(x: -4, y: -4)
                    }
                    // Captain badge
                    if isCaptain {
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(WC.gold)
                            .background(Circle().fill(WC.ink))
                            .offset(x: -4, y: -4)
                    }
                }
                // Energy bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(WC.fill)
                        Capsule().fill(energyColor(ePct))
                            .frame(width: max(2, geo.size.width * ePct))
                    }
                }.frame(height: 4)
                // Name
                Text(owned.card.funnyName)
                    .font(WC.display(9))
                    .foregroundStyle(isSelected ? WC.inkText : WC.sub)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 72)
            .opacity(isSelected ? 1 : 0.75)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture().onEnded { _ in vm.setCaptain(owned.id) }
        )
    }

    private func energyColor(_ pct: Double) -> Color {
        if pct < 0.25 { return WC.coral }
        if pct < 0.5 { return WC.gold }
        return WC.go
    }

    // MARK: - Tactics rows with impact text

    private func tacticRow<T: CaseIterable & Hashable>(
        _ title: String,
        _ all: [T],
        _ sel: T,
        _ name: KeyPath<T, String>,
        _ impact: KeyPath<T, String>,
        _ set: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(WC.ui(12)).foregroundStyle(WC.sub)
            HStack(spacing: 8) {
                ForEach(Array(all), id: \.self) { v in
                    chip(v[keyPath: name], v == sel) { set(v) }
                }
            }
            Text(sel[keyPath: impact])
                .font(WC.ui(12))
                .foregroundStyle(WC.sub)
                .italic()
        }
    }

    private func chip(_ text: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(text).font(WC.ui(13)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(on ? WC.coral : WC.fill)
                .foregroundStyle(on ? .white : WC.inkText)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kick off

    private var kickOff: some View {
        VStack(spacing: 8) {
            if vm.alreadyFinished {
                Text("Already played this block.").font(WC.ui(13)).foregroundStyle(WC.sub)
            } else if vm.selected.isEmpty {
                Text("Select at least one player above.").font(WC.ui(13)).foregroundStyle(WC.coral)
            } else if !vm.canAfford {
                Text("Need \(vm.entryFee) Cash to play.").font(WC.ui(13)).foregroundStyle(WC.coral)
            } else if vm.hasTiredPlayers {
                Text("Some players are tired — they'll underperform.")
                    .font(WC.ui(12)).foregroundStyle(WC.gold)
            }
            Button {
                vm.kickOff()
            } label: {
                HStack(spacing: 8) {
                    Text("KICK OFF").font(WC.ui(16)).foregroundStyle(.white)
                    CurrencyCost(currency: .coins, amount: vm.entryFee, onColor: true)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(vm.canKickOff ? WC.coral : WC.fill)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canKickOff)
            .opacity(vm.canKickOff ? 1 : 0.5)
        }
    }
}
