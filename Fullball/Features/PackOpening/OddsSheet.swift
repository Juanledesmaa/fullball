import SwiftUI

/// Discloses exact pull odds + the pity rules (App Store requirement for
/// randomized purchases).
struct OddsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Every pull draws one card. Base per-rarity odds are fixed and shown below.")
                        .font(WC.ui(13)).foregroundStyle(WC.sub)

                    PanelCard {
                        VStack(spacing: 0) {
                            ForEach(Rarity.allCases.reversed(), id: \.self) { rarity in
                                HStack {
                                    Circle().fill(rarity.color).frame(width: 10, height: 10)
                                    Text(rarity.displayName).font(WC.display(13))
                                        .foregroundStyle(WC.inkText)
                                    Spacer()
                                    Text(percent(rarity.baseOdds)).font(WC.display(13))
                                        .foregroundStyle(WC.inkText)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                if rarity != .bronze {
                                    Rectangle().fill(WC.lineColor).frame(height: 1)
                                }
                            }
                        }
                    }

                    SectionLabel(title: "Pity rules")
                    ruleRow("Soft pity", "From pull \(GachaEngine.softPityStart), the combined Epic + Icon odds ramp upward each pull.")
                    ruleRow("Hard pity", "Pull \(GachaEngine.hardPity) guarantees an Icon. The counter resets on any Icon.")
                    ruleRow("50/50", "Your first guaranteed Icon may be off-banner. If so, the next guaranteed Icon is the featured card.")

                    Text("Rep is earned only from live matches and is never purchasable.")
                        .font(WC.ui(11)).foregroundStyle(WC.faint)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(ScreenBackground())
            .navigationTitle("Pull Odds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(WC.display(13)).tint(WC.coral)
                }
            }
        }
    }

    private func ruleRow(_ title: String, _ body: String) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(WC.display(11)).tracking(0.6).foregroundStyle(WC.coral)
                Text(body).font(WC.ui(12.5)).foregroundStyle(WC.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
        }
    }

    private func percent(_ v: Double) -> String {
        let p = v * 100
        return p < 1 ? String(format: "%.1f%%", p) : String(format: "%.1f%%", p)
    }
}

#Preview { OddsSheet() }
