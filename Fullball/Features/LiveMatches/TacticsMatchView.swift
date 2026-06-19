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

                // Field preview + roster strip
                fieldSection

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

    // MARK: - Field section (field preview + roster strip)

    private var fieldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR SQUAD").font(WC.ui(12)).foregroundStyle(WC.sub)
                Spacer()
                Text("\(vm.yourFieldedCount)/5")
                    .font(WC.display(11))
                    .foregroundStyle(vm.yourFieldedCount == 0 ? WC.coral : WC.go)
            }

            // Off-position hint
            let offPositionCount = (0..<5).filter { vm.isOffPosition($0) }.count
            if offPositionCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(WC.gold)
                    Text("Off-position players play at 0.5×")
                        .font(WC.ui(11))
                        .foregroundStyle(WC.gold)
                }
            }

            // Field preview (horizontal pitch)
            fieldPreview

            // Roster strip
            rosterStrip
        }
    }

    // MARK: - Field preview

    private var fieldPreview: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Grass background
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x1A5232), Color(hex: 0x0F3A1E)],
                        startPoint: .top, endPoint: .bottom
                    ))

                // Center line
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1.5)
                    .position(x: w * 0.5, y: h * 0.5)

                // Goal mouth — your goal on LEFT
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 8, height: h * 0.4)
                    .position(x: 4, y: h * 0.5)

                // "YOUR GOAL" label
                Text("YOUR\nGOAL")
                    .font(WC.display(7))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .position(x: w * 0.06, y: h * 0.15)

                // Slot circles
                ForEach(0..<5, id: \.self) { i in
                    slotView(index: i, in: CGSize(width: w, height: h))
                        .position(slotPosition(index: i, in: CGSize(width: w, height: h)))
                }
            }
        }
        // Landscape aspect within portrait
        .aspectRatio(1.75, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    /// Slot positions on the horizontal pitch:
    /// GK (i=0) near left goal; DEF (i=1) left-center; MID×2 (i=2,3) center;
    /// FWD (i=4) right side.
    ///
    /// X increases left→right (attacking direction).
    /// Y positions: GK centered; DEF/FWD centered; MID staggered top+bottom.
    private func slotPosition(index i: Int, in size: CGSize) -> CGPoint {
        let w = size.width, h = size.height
        switch i {
        case 0: return CGPoint(x: w * 0.10, y: h * 0.50)   // GK
        case 1: return CGPoint(x: w * 0.30, y: h * 0.50)   // DEF
        case 2: return CGPoint(x: w * 0.52, y: h * 0.25)   // MID top
        case 3: return CGPoint(x: w * 0.52, y: h * 0.75)   // MID bottom
        case 4: return CGPoint(x: w * 0.72, y: h * 0.50)   // FWD
        default: return CGPoint(x: w * 0.5, y: h * 0.5)
        }
    }

    @ViewBuilder
    private func slotView(index i: Int, in size: CGSize) -> some View {
        let slotPos = vm.slots[i]
        let occupied = vm.slotPlayer(i)
        let isCaptain = occupied?.id == vm.captainID
        let offPos = vm.isOffPosition(i)

        ZStack {
            if let oc = occupied {
                // Filled slot: show avatar
                Circle()
                    .fill(oc.card.rarity.color.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(
                            isCaptain ? WC.gold : oc.card.rarity.color,
                            lineWidth: isCaptain ? 3 : 1.5
                        )
                    )
                AvatarView(card: oc.card)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                // Off-position badge
                if offPos {
                    Text("0.5×")
                        .font(WC.display(7))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3).padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 14, y: 16)
                }

                // Captain badge
                if isCaptain {
                    Text("C")
                        .font(WC.display(8))
                        .foregroundStyle(WC.ink)
                        .padding(3)
                        .background(Circle().fill(WC.gold))
                        .offset(x: 16, y: -16)
                }

            } else {
                // Empty slot: show required position
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5, antialiased: true)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.07)))
                Text(slotPos.rawValue)
                    .font(WC.display(10))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        // Tap filled slot → set captain
        .onTapGesture {
            if let oc = occupied {
                vm.setCaptain(oc.id)
            }
        }
        // Long-press → clear slot
        .onLongPressGesture {
            vm.clearSlot(i)
        }
        // Drop destination: accept a card ID string
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            vm.assign(id, toSlot: i)
            return true
        }
        // "X" clear button when filled
        .overlay(alignment: .topTrailing) {
            if occupied != nil {
                Button {
                    vm.clearSlot(i)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    // MARK: - Roster strip

    private var rosterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.ownedForSelection()) { owned in
                    rosterTile(owned)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func rosterTile(_ owned: OwnedCard) -> some View {
        let isAssigned = vm.assignedIDs.contains(owned.id)
        let e = vm.energy(owned.id)
        let ePct = Double(e) / Double(EnergyRules.maxEnergy)

        return VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                AvatarView(card: owned.card)
                    .frame(width: 58, height: 87)
                    .background(owned.card.rarity.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isAssigned ? owned.card.rarity.color : WC.lineColor,
                                lineWidth: isAssigned ? 2.5 : 1
                            )
                    )
                // Assigned checkmark badge
                if isAssigned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(WC.go)
                        .background(Circle().fill(WC.ink))
                        .offset(x: -4, y: -4)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text(owned.card.player.position.rawValue)
                    .font(WC.display(8)).tracking(0.4).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(positionColor(owned.card.player.position)))
                    .padding(3)
            }
            // Energy bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WC.fill)
                    Capsule().fill(energyColor(ePct))
                        .frame(width: max(2, geo.size.width * ePct))
                }
            }.frame(height: 4)
            // Overall
            Text("\(owned.effectiveStats.overall)")
                .font(WC.display(9))
                .foregroundStyle(isAssigned ? WC.inkText : WC.sub)
                .lineLimit(1)
            // Name
            Text(owned.card.funnyName)
                .font(WC.display(8))
                .foregroundStyle(isAssigned ? WC.inkText : WC.sub)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(width: 72)
        .opacity(isAssigned ? 1 : 0.75)
        .draggable(owned.id)
    }

    /// Distinct color per position so the role reads at a glance.
    private func positionColor(_ pos: Position) -> Color {
        switch pos {
        case .gk:  return WC.gold
        case .def: return Color(hex: 0x4A90D9)
        case .mid: return WC.go
        case .fwd: return WC.coral
        }
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
            } else if vm.yourFieldedCount == 0 {
                Text("Drag players into the field slots above.").font(WC.ui(13)).foregroundStyle(WC.coral)
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
