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
            eventFeed
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
        ZStack {
            // Equal-width side blocks ensure the center score is truly centered
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOU").font(WC.display(10)).tracking(0.8).foregroundStyle(WC.coral)
                    Text(vm.fixture.homeTag).font(WC.display(14)).foregroundStyle(WC.inkText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(width: 90) // reserved for center score block

                VStack(alignment: .trailing, spacing: 2) {
                    Text("OPP").font(WC.display(10)).tracking(0.8).foregroundStyle(WC.sub)
                    Text(vm.opponentName.uppercased()).font(WC.display(14)).foregroundStyle(WC.inkText)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Score + clock centered over the layout
            VStack(spacing: 2) {
                Text("\(vm.homeGoals) – \(vm.awayGoals)")
                    .font(WC.display(34)).foregroundStyle(WC.inkText)
                if !vm.minuteLabel.isEmpty {
                    Text(vm.minuteLabel)
                        .font(WC.display(10)).tracking(0.6)
                        .foregroundStyle(vm.phase == .fullTime ? WC.gold : WC.sub)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
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
        .aspectRatio(1.5, contentMode: .fit)     // landscape within portrait
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
                .frame(width: 38, height: 38)
                .overlay(
                    Circle().stroke(
                        isBallHolder ? WC.gold : (card?.rarity.color ?? WC.coral),
                        lineWidth: isBallHolder ? 3 : 1.5
                    )
                )
            // Portrait inside circle
            if let card {
                AvatarView(card: card)
                    .frame(width: 38, height: 38)
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
                    .offset(x: 14, y: -14)
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
                .frame(width: 38, height: 38)
                .overlay(
                    Circle().stroke(
                        isBallHolder ? WC.gold : Color.white.opacity(0.4),
                        lineWidth: isBallHolder ? 3 : 1.5
                    )
                )
            if let card {
                AvatarView(card: card)
                    .frame(width: 38, height: 38)
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

    /// Depth of a position column. Home defends the left goal, so its forwards
    /// push right (toward center); away mirrors. Matches the setup field layout.
    private func depthX(for pos: Position, isHome: Bool) -> CGFloat {
        let homeFrac: CGFloat
        switch pos {
        case .gk:  homeFrac = 0.05
        case .def: homeFrac = 0.17
        case .mid: homeFrac = 0.29
        case .fwd: homeFrac = 0.41   // leaves a wider gap between the two teams at center
        }
        return isHome ? homeFrac : (1 - homeFrac)
    }

    private func horizontalSlots(_ players: [MatchPlayer], isHome: Bool, in size: CGSize) -> [Slot] {
        guard !players.isEmpty else { return [] }
        var result: [Slot] = []
        // Group into position columns (GK → DEF → MID → FWD); stack each column vertically.
        for pos in [Position.gk, .def, .mid, .fwd] {
            let group = players.filter { $0.position == pos }
            guard !group.isEmpty else { continue }
            let x = size.width * depthX(for: pos, isHome: isHome)
            for (i, p) in group.enumerated() {
                let frac = Double(i + 1) / Double(group.count + 1)
                result.append(Slot(id: p.id, player: p,
                                   point: CGPoint(x: x, y: size.height * frac)))
            }
        }
        return result
    }

    // MARK: - Event feed (running list below the pitch)

    /// Scoring/keeper events played so far, newest first (turnovers omitted).
    private var playedEvents: [PossessionEvent] {
        guard let res = vm.result else { return [] }
        return Array(res.events.prefix(vm.minuteIndex))
            .filter { $0.outcome != .turnover }
            .reversed()
    }

    private var eventFeed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if playedEvents.isEmpty {
                    Text("Kick off!").font(WC.ui(13)).foregroundStyle(WC.sub)
                }
                ForEach(playedEvents) { feedRow($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 170)
        .animation(.default, value: vm.minuteIndex)
    }

    private func feedRow(_ e: PossessionEvent) -> some View {
        let total = vm.result?.events.count ?? FutsalRules.possessionCount
        let minute = Int((Double(e.index + 1) / Double(max(1, total))) * 90)
        let who = vm.catalogCard(e.ballPlayerID)?.displayName ?? "Player"
        let side = e.attackingHome ? vm.fixture.homeTag : vm.opponentName.uppercased()
        let (icon, label, tint): (String, String, Color) = {
            switch e.outcome {
            case .goal:     return ("soccerball", "GOAL", WC.gold)
            case .save:     return ("hand.raised.fill", "Save", WC.sub)
            case .miss:     return ("wind", "Miss", WC.sub)
            case .turnover: return ("arrow.uturn.left", "Turnover", WC.sub)
            }
        }()
        return HStack(spacing: 8) {
            Text("\(minute)'").font(WC.display(11)).foregroundStyle(WC.sub)
                .frame(width: 30, alignment: .leading)
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint)
            Text("\(label) — \(who)").font(WC.ui(13))
                .foregroundStyle(e.outcome == .goal ? WC.inkText : WC.sub).lineLimit(1)
            Spacer()
            Text(side).font(WC.display(9)).foregroundStyle(WC.sub)
        }
    }

    // MARK: - Full time panel

    private var fullTime: some View {
        VStack(spacing: 10) {
            Text("FULL TIME").font(WC.display(22)).foregroundStyle(WC.gold)
            if let p = vm.payout {
                // Single horizontal row — compact chips that scale down before wrapping
                HStack(spacing: 8) {
                    rewardChip(label: "+\(p.cash)", currency: .coins)
                    rewardChip(label: "+\(p.rep)", currency: .formTokens)
                    rewardPointsChip(points: p.points)
                    if p.wonBonus {
                        rewardChip(label: "+1", currency: .tickets)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

    private func rewardChip(label: String, currency: Currency) -> some View {
        HStack(spacing: 3) {
            Image(systemName: currency.symbol).font(.system(size: 11)).foregroundStyle(currency.tint)
            Text(label).font(WC.display(12)).foregroundStyle(WC.inkText)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(WC.fill))
    }

    private func rewardPointsChip(points: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.circle.fill").font(.system(size: 11)).foregroundStyle(WC.gold)
            Text("+\(points) pts").font(WC.display(12)).foregroundStyle(WC.inkText)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(WC.fill))
    }
}
