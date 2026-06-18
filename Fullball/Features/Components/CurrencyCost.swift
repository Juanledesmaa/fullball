import SwiftUI

/// A cost label shown as the currency's SF-symbol icon + amount, tinted like
/// the wallet bar pill. Drop inside any spend button to replace a bare number.
struct CurrencyCost: View {
    let currency: Currency
    let amount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: currency.symbol)
                .font(.system(size: 12))
            Text("\(amount)")
                .font(WC.display(13))
        }
        .foregroundStyle(currency.tint)
    }
}
