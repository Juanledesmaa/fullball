import SwiftUI

/// Light-burst reveal of pulled cards. Staggered fade-in, rarity flare for
/// the best pull, and haptics. Tap to dismiss.
struct PackRevealView: View {
    let results: [PullResult]
    let onDone: () -> Void

    @State private var shown = false
    @State private var flare = false

    private var bestRarity: Rarity { results.map(\.card.rarity).max() ?? .bronze }
    private var isBigPull: Bool { bestRarity >= .epic }

    var body: some View {
        ZStack {
            WC.ink.opacity(0.93).ignoresSafeArea()

            // Rarity flare: a soft rotating halo behind the reveal for epic+.
            if isBigPull {
                AngularGradient(colors: [bestRarity.color.opacity(0.0), bestRarity.color.opacity(0.55),
                                         bestRarity.color.opacity(0.0)],
                                center: .center)
                    .blur(radius: 40)
                    .frame(width: 360, height: 360)
                    .rotationEffect(.degrees(flare ? 360 : 0))
                    .opacity(shown ? 0.9 : 0)
                    .animation(.linear(duration: 6).repeatForever(autoreverses: false), value: flare)
            }
            RadialGradient(colors: [bestRarity.color.opacity(shown ? 0.5 : 0), .clear],
                           center: .center, startRadius: 4, endRadius: 320)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.6), value: shown)

            VStack(spacing: 16) {
                Text(results.count > 1 ? "10× PULL" : "NEW PULL")
                    .font(WC.display(13)).tracking(2).foregroundStyle(.white.opacity(0.7))
                    .opacity(shown ? 1 : 0)

                if results.count == 1, let r = results.first {
                    singleReveal(r)
                } else {
                    multiReveal
                }

                Text("TAP TO CONTINUE")
                    .font(WC.display(11)).tracking(1.5).foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
                    .opacity(shown ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: shown)
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .sensoryFeedback(trigger: shown) { _, now in
            guard now else { return nil }
            return isBigPull ? .success : .impact(weight: .light)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown = true }
            flare = true
        }
    }

    private func singleReveal(_ r: PullResult) -> some View {
        VStack(spacing: 10) {
            CardHero(card: r.card, stars: 0, overall: r.card.player.stats.overall)
                .frame(maxWidth: 280)
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)
                .rotation3DEffect(.degrees(shown ? 0 : 35), axis: (x: 0, y: 1, z: 0))
                .animation(.spring(response: 0.5, dampingFraction: 0.62), value: shown)
            if r.isNew {
                Text("NEW").font(WC.display(12)).tracking(1).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(WC.coral))
            } else {
                Text("DUPLICATE · +1 LIMIT-BREAK COPY")
                    .font(WC.display(10)).tracking(0.8).foregroundStyle(WC.gold)
            }
        }
        .opacity(shown ? 1 : 0)
    }

    private var multiReveal: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, r in
                    VStack(spacing: 4) {
                        CardArt(card: r.card, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(r.card.rarity.color, lineWidth: 1.5))
                        HStack(spacing: 4) {
                            Text(r.card.funnyName).font(WC.display(9))
                                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                            if r.isNew {
                                Text("NEW").font(WC.display(7)).foregroundStyle(WC.ink)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Capsule().fill(WC.coral))
                            }
                        }
                    }
                    // Staggered cascade — each tile fades + lifts in turn.
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.82)
                    .offset(y: shown ? 0 : 14)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75)
                        .delay(Double(index) * 0.045), value: shown)
                }
            }
        }
        .frame(maxHeight: 460)
    }
}
