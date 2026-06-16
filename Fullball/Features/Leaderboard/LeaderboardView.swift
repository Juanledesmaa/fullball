import SwiftUI

struct LeaderboardView: View {
    @State private var vm: LeaderboardViewModel

    init(container: AppContainer) {
        _vm = State(initialValue: LeaderboardViewModel(container: container))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(kicker: "Top agencies · by points", title: "Agencies") {
                if let rank = vm.currentUserRank {
                    VStack(spacing: -2) {
                        Text("#\(rank)").font(WC.display(20)).foregroundStyle(WC.coral)
                        Text("YOU").font(WC.display(8)).tracking(1).foregroundStyle(WC.sub)
                    }
                }
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(vm.entries) { entry in row(entry) }
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        PanelCard(borderColor: entry.isCurrentUser ? WC.coral : WC.lineColor,
                  borderWidth: entry.isCurrentUser ? 2 : 1.5) {
            HStack(spacing: 12) {
                Text("\(entry.rank)").font(WC.display(15))
                    .foregroundStyle(entry.rank <= 3 ? WC.coral : WC.sub)
                    .frame(width: 30, alignment: .leading)
                ZStack {
                    Circle().fill(entry.isCurrentUser ? WC.coralSoft : WC.fill)
                        .frame(width: 34, height: 34)
                    Image(systemName: entry.isCurrentUser ? "person.fill" : "person")
                        .font(.system(size: 14))
                        .foregroundStyle(entry.isCurrentUser ? WC.coral : WC.sub)
                }
                Text(entry.userName).font(WC.display(14)).foregroundStyle(WC.inkText)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.points)").font(WC.display(15)).foregroundStyle(WC.inkText)
                    Text("PTS").font(WC.display(8)).tracking(0.8).foregroundStyle(WC.faint)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
    }
}

#Preview {
    LeaderboardView(container: .preview())
}
