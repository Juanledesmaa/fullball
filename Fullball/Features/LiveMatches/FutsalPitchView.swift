import SwiftUI

struct FutsalPitchView: View {
    @Bindable var vm: TacticsMatchViewModel
    var onClose: () -> Void

    private let tick = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    // Ball animation state
    @State private var ballPoint: CGPoint = .zero
    @State private var ballScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 14) {
            scoreboard
            pitch
            ticker
            if vm.phase == .fullTime { fullTime }
            Spacer(minLength: 0)
        }
        .padding(18)
        .onReceive(tick) { _ in
            if vm.phase == .playing { vm.step() }
        }
    }

    // MARK: - Scoreboard

    private var scoreboard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOU").font(WC.display(10)).tracking(0.8).foregroundStyle(WC.coral)
                Text(vm.fixture.homeTag).font(WC.display(14)).foregroundStyle(WC.inkText)
            }
            Spacer()
            Text("\(vm.homeGoals) – \(vm.awayGoals)")
                .font(WC.display(34)).foregroundStyle(WC.inkText)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("OPP").font(WC.display(10)).tracking(0.8).foregroundStyle(WC.sub)
                Text(vm.opponentName.uppercased()).font(WC.display(14)).foregroundStyle(WC.inkText)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: - Pitch (landscape within portrait)

    private var pitch: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Grass
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x1A5232), Color(hex: 0x0F3A1E)],
                        startPoint: .top, endPoint: .bottom
                    ))

                // Center line (vertical within landscape)
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1.5)
                    .position(x: size.width * 0.5, y: size.height * 0.5)

                // Center circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: min(size.height * 0.45, 80), height: min(size.height * 0.45, 80))
                    .position(x: size.width * 0.5, y: size.height * 0.5)

                // Goal mouth indicators
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 10, height: size.height * 0.45)
                    .position(x: 5, y: size.height * 0.5)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 10, height: size.height * 0.45)
                    .position(x: size.width - 5, y: size.height * 0.5)

                // Opponent players (RIGHT side)
                ForEach(horizontalSlots(vm.opponent.players, isHome: false, in: size), id: \.id) { item in
                    opponentCircle(item.player, isBallHolder: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == false)
                        .position(item.point)
                }

                // Home players (LEFT side)
                ForEach(horizontalSlots(vm.myFieldedCards(), isHome: true, in: size), id: \.id) { item in
                    homeCircle(item.player, isBallHolder: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == true)
                        .position(item.point)
                }

                // Animated ball
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(hex: 0x333333), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                    .scaleEffect(ballScale)
                    .position(ballPoint == .zero ? CGPoint(x: size.width * 0.5, y: size.height * 0.5) : ballPoint)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: ballPoint)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: ballScale)
            }
            .onChange(of: vm.minuteIndex) { _, _ in
                updateBallPosition(in: size)
            }
            .onAppear {
                ballPoint = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            }
        }
        .aspectRatio(1.75, contentMode: .fit)     // landscape within portrait
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ball position update

    private func updateBallPosition(in size: CGSize) {
        guard let event = vm.lastEvent else { return }

        let allHomeSlots = horizontalSlots(vm.myFieldedCards(), isHome: true, in: size)
        let allAwaySlots = horizontalSlots(vm.opponent.players, isHome: false, in: size)

        let targetSlot = (allHomeSlots + allAwaySlots).first { $0.id == event.ballPlayerID }
        let target = targetSlot?.point ?? CGPoint(x: size.width * 0.5, y: size.height * 0.5)

        switch event.outcome {
        case .goal:
            // Animate to player, then toward the attacked goal
            let goalX: CGFloat = event.attackingHome ? size.width * 0.05 : size.width * 0.95
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                ballPoint = target
                ballScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    ballPoint = CGPoint(x: goalX, y: size.height * 0.5)
                    ballScale = 0.8
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        ballScale = 1.0
                    }
                }
            }
        case .save, .miss:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                ballPoint = target
                ballScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { ballScale = 1.0 }
            }
        case .turnover:
            // Small nudge toward midfield
            let midX = size.width * 0.5
            let nudge = CGPoint(
                x: (target.x + midX) / 2,
                y: (target.y + size.height * 0.5) / 2
            )
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                ballPoint = nudge
                ballScale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { ballScale = 1.0 }
            }
        }
    }

    // MARK: - Player circles

    private func homeCircle(_ player: MatchPlayer, isBallHolder: Bool) -> some View {
        let owned = vm.ownedCard(player.id)
        let card = owned?.card
        return ZStack {
            Circle()
                .fill(card?.rarity.color.opacity(0.85) ?? WC.coral.opacity(0.85))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().stroke(
                        isBallHolder ? WC.gold : (card?.rarity.color ?? WC.coral),
                        lineWidth: isBallHolder ? 3 : 1.5
                    )
                )
            // Portrait inside circle
            if let card {
                AvatarView(card: card)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: player.position.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
            // Captain marker
            if player.id == vm.captainID {
                Text("C").font(WC.display(8)).foregroundStyle(WC.ink)
                    .padding(2).background(Circle().fill(WC.gold))
                    .offset(x: 16, y: -16)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: isBallHolder ? 6 : 2, x: 0, y: 2)
        .scaleEffect(isBallHolder ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isBallHolder)
    }

    private func opponentCircle(_ player: MatchPlayer, isBallHolder: Bool) -> some View {
        let card = vm.catalogCard(player.id)
        return ZStack {
            Circle()
                .fill(Color(hex: 0x1C3A5E).opacity(0.9))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().stroke(
                        isBallHolder ? WC.gold : Color.white.opacity(0.4),
                        lineWidth: isBallHolder ? 3 : 1.5
                    )
                )
            if let card {
                AvatarView(card: card)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: player.position.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .shadow(color: .black.opacity(0.35), radius: isBallHolder ? 6 : 2, x: 0, y: 2)
        .scaleEffect(isBallHolder ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isBallHolder)
    }

    // MARK: - Slot layout (horizontal: LEFT=home, RIGHT=away)

    private struct Slot { let id: String; let player: MatchPlayer; let point: CGPoint }

    private func horizontalSlots(_ players: [MatchPlayer], isHome: Bool, in size: CGSize) -> [Slot] {
        guard !players.isEmpty else { return [] }
        let gk = players.first { $0.position == .gk }
        let outs = players.filter { $0.position != .gk }

        // Home = LEFT side (x 0.05..0.45), Away = RIGHT side (x 0.55..0.95)
        let gkX: CGFloat = isHome ? 0.07 : 0.93
        let outX: CGFloat = isHome ? 0.32 : 0.68   // outfield column

        var result: [Slot] = []
        if let gk {
            result.append(Slot(id: gk.id, player: gk,
                               point: CGPoint(x: size.width * gkX, y: size.height * 0.5)))
        }
        for (i, p) in outs.enumerated() {
            let frac = Double(i + 1) / Double(outs.count + 1)
            let y = size.height * frac
            result.append(Slot(id: p.id, player: p,
                               point: CGPoint(x: size.width * outX, y: y)))
        }
        return result
    }

    // MARK: - Ticker

    private var ticker: some View {
        Text(eventText)
            .font(WC.ui(14))
            .foregroundStyle(WC.inkText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.default, value: vm.minuteIndex)
    }

    private var eventText: String {
        guard let e = vm.lastEvent else { return "Kick off!" }
        let who = vm.catalogCard(e.ballPlayerID)?.displayName ?? "#\(e.ballPlayerID)"
        switch e.outcome {
        case .goal:     return "⚽ GOAL — \(who)"
        case .save:     return "🧤 Save"
        case .miss:     return "💨 Miss — \(who)"
        case .turnover: return "↩︎ Turnover"
        }
    }

    // MARK: - Full time panel

    private var fullTime: some View {
        VStack(spacing: 10) {
            Text("FULL TIME").font(WC.display(22)).foregroundStyle(WC.gold)
            if let p = vm.payout {
                HStack(spacing: 12) {
                    payoutPill("+\(p.points) pts", icon: "star.circle.fill", color: WC.gold)
                    payoutPill("+\(p.cash)", icon: Currency.coins.symbol, color: Currency.coins.tint)
                    payoutPill("+\(p.rep) rep", icon: "chart.bar.fill", color: WC.sub)
                    if p.wonBonus {
                        payoutPill("+1", icon: Currency.tickets.symbol, color: Currency.tickets.tint)
                    }
                }
            }
            Button("Done") { onClose() }
                .font(WC.ui(15))
                .padding(.horizontal, 28).padding(.vertical, 11)
                .background(WC.coral).foregroundStyle(.white).clipShape(Capsule())
        }
        .padding(16)
        .background(WC.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(WC.gold, lineWidth: 1.5))
    }

    private func payoutPill(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(label).font(WC.display(12)).foregroundStyle(WC.inkText)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(WC.fill))
    }
}
