import SwiftUI
import UIKit

/// Bundled illustrated portraits, mapped deterministically to a card id.
/// Replaces the old procedural (pixel / vector) avatars.
enum AvatarAssets {
    /// Number of `avatar_NNN.jpg` files bundled under Resources/Avatars.
    static let count = 150

    @MainActor private static let cache = NSCache<NSString, UIImage>()

    @MainActor
    static func image(_ index: Int) -> UIImage? {
        let name = String(format: "avatar_%03d", index)
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }

    static func index(for id: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(h % UInt64(max(1, count)))
    }
}

/// A card's portrait for cards/grids: fills the frame, anchored to the TOP
/// so the face is kept (source art is a vertical full-body portrait).
struct AvatarView: View {
    let card: Card

    var body: some View {
        GeometryReader { geo in
            portrait
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .clipped()
        }
    }

    @ViewBuilder private var portrait: some View {
        if let img = AvatarAssets.image(AvatarAssets.index(for: card.id)) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(card.rarity.color.opacity(0.3))
                Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

/// The full vertical portrait (uncropped), for the detail screen.
struct CardPortraitFull: View {
    let card: Card
    var body: some View {
        if let img = AvatarAssets.image(AvatarAssets.index(for: card.id)) {
            Image(uiImage: img).resizable().scaledToFit()
        } else {
            ZStack {
                Rectangle().fill(card.rarity.color.opacity(0.3))
                Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
