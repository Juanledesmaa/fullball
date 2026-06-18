import SwiftUI

/// Pick which owned cards to field for the matchday and who captains.
/// Players whose nation is in a live match are flagged and sorted first.
struct LineupSheet: View {
    let container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @State private var version = 0   // bump to refresh after edits

    private var lineup: any LineupService { container.lineup }

    private func isNationLive(_ tag: String) -> Bool {
        container.slate.fixtures.contains { $0.status == .live && ($0.homeTag == tag || $0.awayTag == tag) }
    }

    private var owned: [OwnedCard] {
        _ = version
        return container.collection.owned().sorted { a, b in
            let la = isNationLive(a.card.player.nationTag), lb = isNationLive(b.card.player.nationTag)
            if la != lb { return la }                       // live-eligible first
            return a.effectiveStats.overall > b.effectiveStats.overall
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if owned.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(owned) { row($0) }
                        }
                        .padding(16)
                    }
                }
            }
            .background(ScreenBackground())
            .navigationTitle("Matchday Lineup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(lineup.count) / \(lineup.maxFielded) fielded")
                        .font(WC.display(12)).foregroundStyle(WC.coral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(WC.display(13)).tint(WC.coral)
                }
            }
        }
    }

    private func row(_ owned: OwnedCard) -> some View {
        let fielded = lineup.isFielded(owned.id)
        let captain = lineup.isCaptain(owned.id)
        let live = isNationLive(owned.card.player.nationTag)
        return PanelCard(borderColor: fielded ? WC.coral : WC.lineColor,
                         borderWidth: fielded ? 2 : 1.5) {
            HStack(spacing: 10) {
                AvatarView(card: owned.card).frame(width: 40, height: 60)
                    .background(owned.card.rarity.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(owned.card.funnyName).font(WC.display(13))
                            .foregroundStyle(WC.inkText).lineLimit(1).minimumScaleFactor(0.6)
                        if live {
                            HStack(spacing: 3) { LiveDot()
                                Text("LIVE").font(WC.display(7.5)).tracking(0.5).foregroundStyle(WC.coral) }
                        }
                    }
                    Text("\(owned.card.player.position.rawValue) · OVR \(owned.effectiveStats.overall)")
                        .font(WC.ui(10)).foregroundStyle(WC.sub)
                }
                Spacer()
                // captain toggle (only when fielded)
                if fielded {
                    Button { lineup.setCaptain(captain ? nil : owned.id); version += 1 } label: {
                        Image(systemName: captain ? "c.circle.fill" : "c.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(captain ? WC.gold : WC.faint)
                    }.buttonStyle(.plain)
                }
                // field toggle
                Button { lineup.toggleField(owned.id); version += 1 } label: {
                    Image(systemName: fielded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(fielded ? WC.coral : WC.sub)
                }.buttonStyle(.plain)
                .disabled(!fielded && lineup.count >= lineup.maxFielded)
                .opacity((!fielded && lineup.count >= lineup.maxFielded) ? 0.35 : 1)
            }
            .padding(10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.square.badge.video").font(.system(size: 40))
                .foregroundStyle(WC.faint)
            Text("No cards to field yet").font(WC.display(16)).foregroundStyle(WC.inkText)
            Text("Open a pack first, then field your players here to earn points in live matches.")
                .font(WC.ui(12)).foregroundStyle(WC.sub)
                .multilineTextAlignment(.center).padding(.horizontal, 36)
            Button { container.navigator.go(.packs); dismiss() } label: {
                Text("OPEN PACKS").font(WC.display(13)).foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(WC.coral))
            }.buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
