import SwiftUI

struct FutsalPitchView: View {
    @Bindable var vm: TacticsMatchViewModel
    var onClose: () -> Void
    private let tick = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            scoreboard
            pitch
            ticker
            if vm.phase == .fullTime { fullTime }
            Spacer(minLength: 0)
        }
        .padding(18)
        .onReceive(tick) { _ in if vm.phase == .playing { vm.step() } }
    }

    private var scoreboard: some View {
        HStack {
            Text("YOU").font(WC.ui(13)).foregroundStyle(WC.sub)
            Spacer()
            Text("\(vm.homeGoals) – \(vm.awayGoals)").font(WC.display(30)).foregroundStyle(WC.inkText)
            Spacer()
            Text(vm.opponentName.uppercased()).font(WC.ui(13)).foregroundStyle(WC.sub)
        }
    }

    private var pitch: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x13402A))
                Rectangle().fill(WC.line).frame(height: 1).position(x: geo.size.width / 2, y: geo.size.height / 2)
                ForEach(slots(vm.opponent.players, top: true, in: geo.size)) { item in
                    profile(item.player, tag: vm.fixture.awayTag,
                            isBall: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == false)
                        .position(item.point)
                }
                ForEach(slots(homePlayers(), top: false, in: geo.size)) { item in
                    profile(item.player, tag: vm.fixture.homeTag,
                            isBall: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == true)
                        .position(item.point)
                }
            }
        }
        .frame(height: 360)
    }

    private var ticker: some View {
        Text(eventText).font(WC.ui(14)).foregroundStyle(WC.inkText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.default, value: vm.minuteIndex)
    }

    private var fullTime: some View {
        VStack(spacing: 8) {
            Text("FULL TIME").font(WC.display(20)).foregroundStyle(WC.gold)
            if let p = vm.payout {
                Text("+\(p.points) pts · +\(p.cash) Cash · +\(p.rep) Rep" + (p.wonBonus ? " · +1 Scout" : ""))
                    .font(WC.ui(14)).foregroundStyle(WC.inkText).multilineTextAlignment(.center)
            }
            Button("Done") { onClose() }.font(WC.ui(15))
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(WC.coral).foregroundStyle(.white).clipShape(Capsule())
        }
    }

    private func homePlayers() -> [MatchPlayer] {
        vm.myFieldedCards().map { MatchPlayer(id: $0.id, position: $0.card.player.position, stats: $0.effectiveStats) }
    }

    private struct Slot: Identifiable { let id: String; let player: MatchPlayer; let point: CGPoint }
    private func slots(_ players: [MatchPlayer], top: Bool, in size: CGSize) -> [Slot] {
        guard !players.isEmpty else { return [] }
        let rowYs: [CGFloat] = top ? [0.12, 0.30] : [0.88, 0.70]
        let gk = players.first { $0.position == .gk }
        let outs = players.filter { $0.position != .gk }
        var result: [Slot] = []
        if let gk { result.append(Slot(id: gk.id, player: gk, point: CGPoint(x: size.width * 0.5, y: size.height * rowYs[0]))) }
        for (i, p) in outs.enumerated() {
            let x = size.width * CGFloat(Double(i + 1) / Double(outs.count + 1))
            result.append(Slot(id: p.id, player: p, point: CGPoint(x: x, y: size.height * rowYs[1])))
        }
        return result
    }

    private func profile(_ p: MatchPlayer, tag: String, isBall: Bool) -> some View {
        ZStack {
            Circle().fill(WC.cardBG).frame(width: 42, height: 42)
                .overlay(Circle().stroke(isBall ? WC.gold : WC.line, lineWidth: isBall ? 3 : 1))
            Text(tag.prefix(3)).font(WC.ui(10)).foregroundStyle(WC.sub)
            if isBall { Circle().fill(.white).frame(width: 10, height: 10).offset(x: 16, y: -16) }
        }
    }

    private var eventText: String {
        guard let e = vm.lastEvent else { return "Kick off!" }
        let who = vm.catalogCard(e.ballPlayerID)?.displayName ?? "#\(e.ballPlayerID)"
        switch e.outcome {
        case .goal: return "GOAL — \(who)"
        case .save: return "Save"
        case .miss: return "Miss — \(who)"
        case .turnover: return "Turnover"
        }
    }
}
