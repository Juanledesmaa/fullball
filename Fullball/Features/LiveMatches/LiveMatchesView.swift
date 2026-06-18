import SwiftUI

struct LiveMatchesView: View {
    let container: AppContainer
    @State private var vm: LiveMatchesViewModel
    @State private var activeFixture: Fixture?

    init(container: AppContainer) {
        self.container = container
        _vm = State(initialValue: LiveMatchesViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(kicker: "Pick your squad · play each match", title: "Live")
            ScrollView {
                VStack(spacing: 14) {
                    matchdayHero
                    HStack(alignment: .firstTextBaseline) {
                        Text("MATCHES").font(WC.display(15)).tracking(0.3).foregroundStyle(WC.inkText)
                        Spacer()
                        Text(vm.liveMatchCount > 0 ? "● \(vm.liveMatchCount) live"
                                                   : "Entry \(vm.entryFee) Coins")
                            .font(WC.display(9.5)).tracking(0.6).foregroundStyle(WC.coral)
                    }.padding(.horizontal, 2)
                    refreshSlateButton
                    ForEach(vm.matches) { matchCard($0) }
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
        .overlay(alignment: .top) { toast }
        .fullScreenCover(item: $activeFixture) { fx in
            TacticsMatchView(fixture: fx, container: container, slateID: vm.slateID)
        }
        .onChange(of: activeFixture) { _, newValue in
            if newValue == nil { vm.restore() }
        }
    }

    @ViewBuilder private var toast: some View {
        if let msg = vm.matchResult ?? vm.milestoneToast {
            HStack(spacing: 8) {
                Image(systemName: vm.matchResult != nil ? "flag.checkered" : "rosette")
                    .foregroundStyle(WC.gold)
                Text(msg).font(WC.display(12)).foregroundStyle(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Capsule().fill(WC.ink))
            .overlay(Capsule().strokeBorder(WC.gold, lineWidth: 1.5))
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: vm.matchResult)
            .animation(.spring(response: 0.4), value: vm.milestoneToast)
        }
    }

    // MARK: matchday hero

    private var matchdayHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(WC.ink)
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    LiveDot()
                    Text("MATCHDAY POINTS").font(WC.display(10)).tracking(1.4).foregroundStyle(WC.coral)
                }
                Text("\(vm.sessionPoints)").font(WC.display(46)).foregroundStyle(.white)
                    .contentTransition(.numericText()).animation(.snappy, value: vm.sessionPoints)
                HStack(spacing: 12) {
                    label("CAREER", "\(vm.careerPoints)")
                    label("REP", "\(vm.formTokensEarned)")
                    label("CASH EARNED", "+\(vm.sessionCash)")
                }.padding(.top, 4)
                if let next = vm.nextMilestone {
                    VStack(spacing: 4) {
                        HStack {
                            Text("NEXT REWARD").font(WC.display(8)).tracking(1).foregroundStyle(.white.opacity(0.5))
                            Spacer()
                            Text("\(next.threshold) PTS · +\(next.gems)◆\(next.tickets > 0 ? " +\(next.tickets)🎟" : "")")
                                .font(WC.display(8.5)).foregroundStyle(WC.gold)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15))
                                Capsule().fill(WC.gold).frame(width: max(3, geo.size.width * vm.milestoneProgress))
                            }
                        }.frame(height: 5)
                    }.padding(.horizontal, 24).padding(.top, 8)
                }
            }.padding(.vertical, 18)
        }
    }

    private func label(_ k: String, _ v: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(WC.display(15)).foregroundStyle(.white)
            Text(k).font(WC.display(8)).tracking(0.8).foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: match cards

    private var refreshSlateButton: some View {
        Button { vm.refreshSlate() } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Currency.gems.tint.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 17))
                        .foregroundStyle(Currency.gems.tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("REFRESH MATCHES").font(WC.display(11)).tracking(0.5).foregroundStyle(WC.inkText)
                    Text(vm.liveMatchCount > 0 ? "Finish your live matches first"
                                               : "New slate now · skip the wait")
                        .font(WC.ui(10)).foregroundStyle(WC.sub)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: Currency.gems.symbol).font(.system(size: 11)).foregroundStyle(Currency.gems.tint)
                    Text("\(vm.refreshCost)").font(WC.display(12)).foregroundStyle(WC.inkText)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(WC.fill))
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(WC.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WC.lineColor, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!vm.canRefresh)
        .opacity(vm.canRefresh ? 1 : 0.45)
    }

    private func matchCard(_ match: MatchState) -> some View {
        let isLive = match.phase == .live
        let isDone = match.phase == .fullTime
        return PanelCard(borderColor: isLive ? WC.coral : (isDone ? WC.go : WC.lineColor),
                         borderWidth: isLive ? 2 : 1.5) {
            VStack(spacing: 10) {
                HStack {
                    teamSide(match.fixture.homeTag, alignment: .trailing)
                    matchCenter(match)
                    teamSide(match.fixture.awayTag, alignment: .leading)
                }
                Rectangle().fill(WC.lineColor).frame(height: 1)
                matchFooter(match)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    @ViewBuilder private func matchCenter(_ match: MatchState) -> some View {
        switch match.phase {
        case .lobby:
            VStack(spacing: 2) {
                Text("VS").font(WC.display(16)).foregroundStyle(WC.faint)
                Text(match.fixture.group).font(WC.display(8)).foregroundStyle(WC.faint)
            }.frame(width: 76)
        case .live:
            VStack(spacing: 2) {
                Text("\(match.home)–\(match.away)").font(WC.display(22)).foregroundStyle(WC.inkText)
                HStack(spacing: 4) { LiveDot()
                    Text("\(match.minute)'").font(WC.display(9)).foregroundStyle(WC.coral) }
            }.frame(width: 76)
        case .fullTime:
            VStack(spacing: 2) {
                Text("\(match.home)–\(match.away)").font(WC.display(22)).foregroundStyle(WC.inkText)
                Text("FULL TIME").font(WC.display(8)).tracking(0.5).foregroundStyle(WC.go)
            }.frame(width: 76)
        }
    }

    @ViewBuilder private func matchFooter(_ match: MatchState) -> some View {
        switch match.phase {
        case .lobby:
            HStack {
                CurrencyCost(currency: .coins, amount: vm.entryFee)
                    .font(WC.ui(11))
                Spacer()
                Button { activeFixture = match.fixture } label: {
                    Text("PLAY").font(WC.display(12)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Capsule().fill(WC.coral))
                }
                .buttonStyle(.plain)
            }
        case .live:
            HStack {
                Text("LIVE · match in progress").font(WC.display(10)).tracking(0.4).foregroundStyle(WC.coral)
                Spacer()
                Text("+\(match.pointsEarned) pts").font(WC.display(13)).foregroundStyle(WC.go)
            }
        case .fullTime:
            HStack {
                Text("FINISHED").font(WC.display(10)).tracking(0.5).foregroundStyle(WC.go)
                Spacer()
                if match.wonBonus {
                    Text("+\(LiveRules.winBonusTickets)🎟").font(WC.display(11)).foregroundStyle(WC.gold)
                }
                Text("+\(match.pointsEarned) pts · +\(match.formEarned) rep")
                    .font(WC.display(12)).foregroundStyle(WC.go)
            }
        }
    }

    private func teamSide(_ tag: String, alignment: HorizontalAlignment) -> some View {
        let leading = alignment == .leading
        return HStack(spacing: 8) {
            if !leading { Spacer(minLength: 0) }
            if leading { NationBadge(code: tag, width: 26) }
            Text(tag).font(WC.display(12)).foregroundStyle(WC.inkText)
            if !leading { NationBadge(code: tag, width: 26) }
            if leading { Spacer(minLength: 0) }
        }.frame(maxWidth: .infinity)
    }
}

#Preview {
    LiveMatchesView(container: .preview())
}
