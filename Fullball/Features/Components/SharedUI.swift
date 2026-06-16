import SwiftUI

// MARK: - Screen scaffold

/// Warm paper background used by every screen.
struct ScreenBackground: View {
    var body: some View { WC.screenBG.ignoresSafeArea() }
}

/// Big page header: coral kicker, heavy title, coral underline.
struct ScreenHeader<Trailing: View>: View {
    let kicker: String
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(kicker: String, title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.kicker = kicker
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker.uppercased())
                .font(WC.display(11)).tracking(1.4)
                .foregroundStyle(WC.coral)
            HStack(alignment: .bottom) {
                Text(title.uppercased())
                    .font(WC.display(34)).tracking(-0.5)
                    .foregroundStyle(WC.inkText)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                trailing()
            }
            Capsule().fill(WC.coral).frame(width: 46, height: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/// Heavy uppercase section label with an optional coral trailing note.
struct SectionLabel: View {
    let title: String
    var right: String? = nil
    var rightColor: Color = WC.coral
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased()).font(WC.display(15)).tracking(0.3)
                .foregroundStyle(WC.inkText)
            Spacer()
            if let right {
                Text(right.uppercased()).font(WC.display(9.5)).tracking(0.6)
                    .foregroundStyle(rightColor)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Small bits

struct Kicker: View {
    let text: String
    var color: Color = WC.coral
    var body: some View {
        Text(text.uppercased()).font(WC.display(10.5)).tracking(1.4).foregroundStyle(color)
    }
}

/// Pill chip; filled when active (coral or ink), outlined otherwise.
struct Chip: View {
    let label: String
    var active: Bool = false
    var accent: Bool = false
    var body: some View {
        let bg: Color = active ? (accent ? WC.coral : WC.inkText) : .clear
        let fg: Color = active ? .white : WC.sub
        let border: Color = active ? (accent ? WC.coral : WC.inkText) : WC.lineColor
        Text(label).font(WC.display(11)).tracking(0.3)
            .foregroundStyle(fg)
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(Capsule().fill(bg))
            .overlay(Capsule().strokeBorder(border, lineWidth: 1.5))
    }
}

struct LiveDot: View {
    var body: some View {
        Circle().fill(WC.coral).frame(width: 7, height: 7)
            .overlay(Circle().stroke(WC.coralSoft, lineWidth: 3))
            .frame(width: 13, height: 13)
    }
}

/// Grayscale "flag" stand-in: a striped rounded rect with the nation code.
struct NationBadge: View {
    let code: String
    var width: CGFloat = 30
    var body: some View {
        let h = (width * 0.68).rounded()
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(WC.fillD)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { i in
                    (i == 1 ? Color(hex: 0xD2CCC3) : WC.fillD).opacity(0.6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(code).font(WC.display(min(9, width * 0.28))).tracking(0.2)
                .foregroundStyle(WC.sub)
        }
        .frame(width: width, height: h)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(WC.lineColor, lineWidth: 1))
    }
}

/// A white rounded card surface with a hairline border.
struct PanelCard<Content: View>: View {
    var borderColor: Color = WC.lineColor
    var borderWidth: CGFloat = 1.5
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .background(RoundedRectangle(cornerRadius: 14).fill(WC.cardBG))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(borderColor, lineWidth: borderWidth))
    }
}

/// Small rarity tag chip.
struct RarityTag: View {
    let rarity: Rarity
    var body: some View {
        Text(rarity.displayName.uppercased())
            .font(WC.display(9)).tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(rarity.color))
    }
}

/// Star row for limit-break level.
struct StarRow: View {
    let stars: Int
    let cap: Int
    var size: CGFloat = 11
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<cap, id: \.self) { i in
                Image(systemName: i < stars ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i < stars ? WC.gold : WC.faint)
            }
        }
    }
}
