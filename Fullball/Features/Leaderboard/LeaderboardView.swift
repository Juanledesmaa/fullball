import SwiftUI

struct LeaderboardView: View {
    @State private var vm: LeaderboardViewModel
    private let auth: any AuthService

    /// Persisted locally. Local-only limitation: this name is not written back
    /// to Firestore, so other players still see the server-side display name
    /// ("Agent XXXX" or Apple ID name). It overrides the local row display only.
    @AppStorage("agencyName") private var agencyName: String = ""

    @State private var showRenameAlert = false
    @State private var renameInput: String = ""

    init(container: AppContainer) {
        _vm = State(initialValue: LeaderboardViewModel(container: container))
        self.auth = container.auth
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
                    LinkAccountView(auth: auth, mode: .inline)
                    ForEach(vm.entries) { entry in row(entry) }
                }
                .padding(16)
            }
        }
        .background(ScreenBackground())
        .task { await vm.refresh() }
        .alert("Agency Name", isPresented: $showRenameAlert) {
            TextField("Enter agency name", text: $renameInput)
            Button("Save") {
                let trimmed = renameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                agencyName = trimmed
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a name for your agency (local display only).")
        }
    }

    private func row(_ entry: LeaderboardEntry) -> some View {
        let displayName = entry.isCurrentUser && !agencyName.isEmpty ? agencyName : entry.userName
        return PanelCard(borderColor: entry.isCurrentUser ? WC.coral : WC.lineColor,
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
                Text(displayName).font(WC.display(14)).foregroundStyle(WC.inkText)
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(entry.points)").font(WC.display(15)).foregroundStyle(WC.inkText)
                    Text("PTS").font(WC.display(8)).tracking(0.8).foregroundStyle(WC.faint)
                }
                if entry.isCurrentUser {
                    Button {
                        renameInput = agencyName.isEmpty ? entry.userName : agencyName
                        showRenameAlert = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(WC.coral)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(WC.coralSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
    }
}

#Preview {
    LeaderboardView(container: .preview())
}
