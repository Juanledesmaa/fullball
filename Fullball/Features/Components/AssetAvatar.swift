import SwiftUI
import UIKit

/// A card's portrait for cards/grids: fills the frame, anchored to the TOP
/// so the face is kept (source art is a vertical full-body portrait). Loads
/// from the injected `PlayerImageStore` (memory/disk/Storage); shows a
/// rarity-tinted position placeholder while loading or offline.
struct AvatarView: View {
    let card: Card
    @Environment(\.playerImageStore) private var store
    @State private var img: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let img {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
        }
        .task(id: card.id) { img = await store.image(for: card.imageRef) }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(card.rarity.color.opacity(0.3))
            Image(systemName: card.player.position.symbol).foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// The full vertical portrait (uncropped), for the detail screen.
struct CardPortraitFull: View {
    let card: Card
    @Environment(\.playerImageStore) private var store
    @State private var img: UIImage?

    var body: some View {
        Group {
            if let img {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                ZStack {
                    Rectangle().fill(card.rarity.color.opacity(0.3))
                    Image(systemName: card.player.position.symbol)
                        .font(.largeTitle).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .task(id: card.id) { img = await store.image(for: card.imageRef) }
    }
}

// MARK: - Environment injection

private struct PlayerImageStoreKey: EnvironmentKey {
    static let defaultValue: any PlayerImageStore = MockImageStore()
}
extension EnvironmentValues {
    var playerImageStore: any PlayerImageStore {
        get { self[PlayerImageStoreKey.self] }
        set { self[PlayerImageStoreKey.self] = newValue }
    }
}
