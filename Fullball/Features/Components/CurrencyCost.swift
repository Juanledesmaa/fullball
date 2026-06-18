import SwiftUI

/// A cost label shown as the currency's SF-symbol icon + amount, tinted like
/// the wallet bar pill. Drop inside any spend button to replace a bare number.
/// Set `onColor: true` when placed inside a saturated (coral/green) button fill
/// so the label is readable — renders white instead of the currency tint.
struct CurrencyCost: View {
    let currency: Currency
    let amount: Int
    var onColor: Bool = false   // true → white (for use on saturated button fills)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: currency.symbol)
                .font(.system(size: 12))
            Text("\(amount)")
                .font(WC.display(13))
        }
        .foregroundStyle(onColor ? Color.white.opacity(0.9) : currency.tint)
    }
}
