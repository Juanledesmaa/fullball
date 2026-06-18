import SwiftUI

struct LiveMatchesView: View {
    let container: AppContainer
    @State private var vm: LiveMatchesViewModel
    @State private var showLineup = false

    init(container: AppContainer) {
        self.container = container
        _vm = State(initialValue: LiveMatchesViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(kicker: "Enter matches · field your XI", title: "Live")
            ScrollView {
                VStack(spacing: 14) {
                    matchdayHero
                    lineupSection
                    HStack(alignment: .firstTextBaseline) {
                        Text("MATCHES").font(WC.display(15)).tracking(0.3).foregroundStyle(WC.inkText)
                        Spacer()
                        Text(vm.liveMatchCount > 0 ? "● \(vm.liveMatchCount) live · entry \(vm.entryFee)"
                                                   : "Entry \(vm.entryFee) Coins")
                            .font(WC.display(9.5)).tracking(0.6).foregroundStyle(WC.coral)
                    }.padding(.horizontal, 2)
                    refreshSlateButton
                    ForEach(vm.matches) { matchCard($0) }
                    if !vm.feed.isEmpty {
                        SectionLabel(title: "Match feed")
                        ForEach(vm.feed) { feedRow($0) }
                    }
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
        .overlay(alignment: .top) { toast }
        .sheet(isPresented: $showLineup) { LineupSheet(container: container) }
        // NOTE: deliberately no `.onDisappear { vm.stop() }`. Live matches are a
        // cosmetic drip-feed of an already-deterministic result (fixture.scriptedEvents);
        // cancelling on tab-switch froze in-flight matches until relaunch. Tasks are
        // [weak self] so they keep ticking across tabs and settle in the background;
        // a hard app-kill still finalizes via restore() on next launch.
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

    // MARK: lineup

    private var lineupSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("YOUR MATCHDAY XI").font(WC.display(15)).tracking(0.3).foregroundStyle(WC.inkText)
                Text("\(vm.fieldedCount)/\(vm.maxFielded)").font(WC.display(11)).foregroundStyle(WC.sub)
                Spacer()
                Button { showLineup = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("SET LINEUP").font(WC.display(10)).tracking(0.4)
                    }
                    .foregroundStyle(WC.coral)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(Capsule().strokeBorder(WC.coral, lineWidth: 1.5))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 2)

            let fielded = vm.fieldedCards()
            if fielded.isEmpty {
                Button { showLineup = true } label: { emptyLineupCard }.buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) { ForEach(fielded) { fieldedChip($0) } }.padding(.horizontal, 2)
                }
            }
        }
    }

    private var emptyLineupCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill").font(.system(size: 22)).foregroundStyle(WC.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Field your squad").font(WC.display(13)).foregroundStyle(WC.inkText)
                Text("Pick up to \(vm.maxFielded) cards. Only fielded players score in matches.")
                    .font(WC.ui(11)).foregroundStyle(WC.sub)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(WC.faint)
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(WC.cardBG))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5])).foregroundStyle(WC.coral.opacity(0.7)))
    }

    private func fieldedChip(_ owned: OwnedCard) -> some View {
        let isCaptain = container.lineup.isCaptain(owned.id)
        let live = vm.isNationLive(owned.card.player.nationTag)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                AvatarView(card: owned.card).frame(width: 58, height: 87)
                    .background(owned.card.rarity.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isCaptain ? WC.gold : owned.card.rarity.color, lineWidth: 1.5))
                if isCaptain {
                    Image(systemName: "c.circle.fill").font(.system(size: 15))
                        .foregroundStyle(WC.gold).background(Circle().fill(WC.ink)).offset(x: 5, y: -5)
                }
            }
            HStack(spacing: 3) {
                if live { LiveDot().scaleEffect(0.8) }
                Text(owned.card.funnyName).font(WC.display(9))
                    .foregroundStyle(live ? WC.coral : WC.sub).lineLimit(1).minimumScaleFactor(0.6)
            }
        }.frame(width: 72)
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
                earnersRow(match)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    @ViewBuilder private func earnersRow(_ match: MatchState) -> some View {
        let earners = vm.fieldedPlayers(in: match.fixture)
        let live = match.phase == .live
        Rectangle().fill(WC.lineColor).frame(height: 1)
        if earners.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .font(.system(size: 12)).foregroundStyle(WC.faint)
                Text("None of your clients play here").font(WC.ui(10.5)).foregroundStyle(WC.faint)
                Spacer()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(live ? "EARNING NOW" : "YOUR EARNERS")
                        .font(WC.display(8.5)).tracking(0.8)
                        .foregroundStyle(live ? WC.go : WC.sub)
                    Spacer()
                    Text("\(earners.count) client\(earners.count == 1 ? "" : "s")")
                        .font(WC.display(8.5)).foregroundStyle(WC.faint)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(earners) { earnerChip($0, live: live) }
                    }
                }
            }
        }
    }

    private func earnerChip(_ owned: OwnedCard, live: Bool) -> some View {
        let captain = container.lineup.isCaptain(owned.id)
        return HStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                AvatarView(card: owned.card).frame(width: 26, height: 39)
                    .background(owned.card.rarity.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(captain ? WC.gold : owned.card.rarity.color, lineWidth: 1))
                if live { Circle().fill(WC.go).frame(width: 6, height: 6).offset(x: 2, y: -2) }
            }
            Text(owned.card.funnyName).font(WC.display(8.5))
                .foregroundStyle(WC.inkText).lineLimit(1)
            if captain {
                Text("C").font(WC.display(7)).foregroundStyle(WC.ink)
                    .padding(.horizontal, 3).padding(.vertical, 0.5)
                    .background(Capsule().fill(WC.gold))
            }
        }
        .padding(.trailing, 6)
        .padding(4)
        .background(Capsule().fill(WC.fill))
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
                Text("Entry \(vm.entryFee) Cash").font(WC.ui(11)).foregroundStyle(WC.sub)
                Spacer()
                Button { vm.enter(match) } label: {
                    Text("ENTER · \(vm.entryFee)").font(WC.display(11)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(WC.coral))
                }
                .buttonStyle(.plain)
                .disabled(!vm.canEnter(match))
                .opacity(vm.canEnter(match) ? 1 : 0.4)
            }
        case .live:
            HStack {
                Text("LIVE · earning now").font(WC.display(10)).tracking(0.4).foregroundStyle(WC.coral)
                Spacer()
                Text("+\(match.pointsEarned) pts").font(WC.display(13)).foregroundStyle(WC.go)
            }
        case .fullTime:
            HStack {
                Text("You earned").font(WC.ui(11)).foregroundStyle(WC.sub)
                Spacer()
                if match.wonBonus {
                    Text("+\(LiveRules.winBonusTickets)🎟").font(WC.display(11)).foregroundStyle(WC.gold)
                }
                Text("+\(match.pointsEarned) pts · +\(match.formEarned) form")
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

    private func feedRow(_ item: LiveFeedItem) -> some View {
        PanelCard(borderColor: item.isCaptain ? WC.gold : WC.lineColor,
                  borderWidth: item.isCaptain ? 2 : 1.5) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(item.fielded ? WC.coralSoft : WC.fill).frame(width: 34, height: 34)
                    Image(systemName: item.kind.symbol).font(.system(size: 14))
                        .foregroundStyle(item.fielded ? WC.coral : WC.faint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        NationBadge(code: item.nationTag, width: 20)
                        Text(item.playerName).font(WC.display(12)).foregroundStyle(WC.inkText)
                        if item.isCaptain {
                            Text("C").font(WC.display(8)).foregroundStyle(WC.ink)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(WC.gold))
                        }
                    }
                    Text("\(item.minute)' · \(item.kind.label)").font(WC.ui(10)).foregroundStyle(WC.sub)
                }
                Spacer()
                if item.fielded {
                    HStack(spacing: 3) {
                        if item.isCaptain { Text("×2").font(WC.display(9)).foregroundStyle(WC.gold) }
                        Text(item.points >= 0 ? "+\(item.points)" : "\(item.points)")
                            .font(WC.display(14)).foregroundStyle(item.points >= 0 ? WC.go : WC.coral)
                    }
                } else {
                    Text("NOT FIELDED").font(WC.display(8.5)).tracking(0.5).foregroundStyle(WC.faint)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
        }
    }
}

#Preview {
    LiveMatchesView(container: .preview())
}
