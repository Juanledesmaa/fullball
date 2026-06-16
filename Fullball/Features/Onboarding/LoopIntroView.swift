import SwiftUI

/// One-time intro that makes the core loop legible: Collect → Compete →
/// Climb. Shown on first launch, skippable.
struct LoopIntroView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Step {
        let kicker, title, body, symbol: String
        let color: Color
    }
    private let steps: [Step] = [
        .init(kicker: "Step 1", title: "SIGN",
              body: "You're a football agent. Scout unknown talent in packs, or pay Cash to sign marquee clients on the transfer market. Build your roster.",
              symbol: "signature", color: WC.coral),
        .init(kicker: "Step 2", title: "PLAY",
              body: "Field your clients in live matches. The more they perform on the pitch, the more they're worth to you — in real time.",
              symbol: "dot.radiowaves.left.and.right", color: WC.mint),
        .init(kicker: "Step 3", title: "PROFIT",
              body: "Earn Cash commission and Rep on every performance. Reinvest in bigger clients, develop them, and climb the agency ranks.",
              symbol: "chart.line.uptrend.xyaxis", color: WC.gold),
    ]

    var body: some View {
        ZStack {
            WC.screenBG.ignoresSafeArea()
            // WC2026 spectrum stripe motif along the top.
            VStack {
                HStack(spacing: 0) { ForEach(WC.spectrum.indices, id: \.self) { WC.spectrum[$0] } }
                    .frame(height: 6)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("FULLBALL").font(WC.display(15)).tracking(1).foregroundStyle(WC.inkText)
                    Text("MANAGER").font(WC.display(9)).tracking(1.5).foregroundStyle(WC.coral)
                    Spacer()
                    Button("Skip") { onFinish() }.font(WC.display(12)).tint(WC.sub)
                }
                .padding(.horizontal, 20).padding(.top, 18)

                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { i in
                        stepView(steps[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // dots
                HStack(spacing: 7) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule().fill(i == page ? WC.coral : WC.lineColor)
                            .frame(width: i == page ? 20 : 7, height: 7)
                            .animation(.snappy, value: page)
                    }
                }
                .padding(.bottom, 18)

                Button {
                    if page < steps.count - 1 { withAnimation { page += 1 } } else { onFinish() }
                } label: {
                    Text(page < steps.count - 1 ? "NEXT" : "START PLAYING")
                        .font(WC.display(15)).tracking(0.5).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14).fill(WC.coral))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
        }
    }

    private func stepView(_ s: Step) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(s.color.opacity(0.16)).frame(width: 150, height: 150)
                Circle().strokeBorder(s.color, lineWidth: 3).frame(width: 150, height: 150)
                Image(systemName: s.symbol).font(.system(size: 60)).foregroundStyle(s.color)
            }
            VStack(spacing: 10) {
                Kicker(text: s.kicker, color: s.color)
                Text(s.title).font(WC.display(40)).tracking(-0.5).foregroundStyle(WC.inkText)
                Text(s.body).font(WC.ui(14)).foregroundStyle(WC.sub)
                    .multilineTextAlignment(.center).lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
    }
}

#Preview {
    LoopIntroView(onFinish: {})
}
