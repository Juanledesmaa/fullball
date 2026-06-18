import SwiftUI

/// The art window: the player portrait in a 3:2 vertical (2:3 w:h) container,
/// filling its width — height is always width × 1.5.
struct CardArt: View {
    let card: Card

    var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(AvatarView(card: card))
            .background(card.rarity.color.opacity(0.12))
            .clipped()
    }
}

/// A collection grid tile styled like a trading card.
struct CardTile: View {
    let owned: OwnedCard

    var body: some View {
        let card = owned.card
        VStack(spacing: 0) {
            // header bar — rarity + OVR
            HStack {
                Text(card.rarity.displayName.uppercased())
                    .font(WC.display(8.5)).tracking(0.6).foregroundStyle(.white)
                Spacer()
                Text("\(owned.effectiveStats.overall)")
                    .font(WC.display(13)).foregroundStyle(.white)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(card.rarity.color)

            CardArt(card: card)

            // nameplate
            VStack(alignment: .leading, spacing: 4) {
                Text(card.funnyName).font(WC.display(12))
                    .foregroundStyle(WC.inkText).lineLimit(1).minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    NationBadge(code: card.player.nationTag, width: 22)
                    Text("#\(card.player.shirtNumber) · \(card.player.position.rawValue)")
                        .font(WC.ui(10, weight: .semibold)).foregroundStyle(WC.sub)
                    Spacer()
                    StarRow(stars: owned.instance.stars, cap: card.rarity.starCap, size: 9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(WC.cardBG)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(card.rarity.color, lineWidth: 2))
    }
}

/// A large hero card for the reveal + detail header.
struct CardHero: View {
    let card: Card
    var stars: Int = 0
    var overall: Int? = nil

    var body: some View {
        PanelCard(borderColor: card.rarity.color, borderWidth: 3) {
            VStack(spacing: 0) {
                // top frame strip
                HStack(spacing: 8) {
                    Text(card.rarity.displayName.uppercased())
                        .font(WC.display(11)).tracking(1).foregroundStyle(.white)
                    Spacer()
                    if let overall {
                        Text("OVR \(overall)").font(WC.display(13)).foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [card.rarity.color, card.rarity.color.opacity(0.7)],
                                   startPoint: .leading, endPoint: .trailing))

                CardArt(card: card)

                VStack(spacing: 6) {
                    Text(card.funnyName).font(WC.display(20))
                        .foregroundStyle(WC.inkText)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        NationBadge(code: card.player.nationTag, width: 28)
                        Text("#\(card.player.shirtNumber) · \(card.player.position.displayName.uppercased())")
                            .font(WC.display(10)).tracking(0.6).foregroundStyle(WC.sub)
                    }
                    StarRow(stars: stars, cap: card.rarity.starCap, size: 14)
                        .padding(.top, 2)
                }
                .padding(14)
            }
        }
    }
}
