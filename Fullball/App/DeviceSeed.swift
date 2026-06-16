import Foundation
import UIKit

/// Derives a stable, device-specific seed for procedural match generation.
/// The slate is keyed by the device id + an 8-hour time block, so matches
/// are deterministic-but-personal: stable for a few hours, then refresh.
enum DeviceSeed {
    static let hoursPerBlock = 8

    /// Stable per-install base from identifierForVendor (UDID-equivalent on
    /// iOS), with a persisted UUID fallback.
    static var deviceBase: UInt64 {
        let id = UIDevice.current.identifierForVendor?.uuidString ?? persistedFallbackID()
        return fnv1a(id)
    }

    private static func persistedFallbackID() -> String {
        let key = "fb.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    /// Identifier for the current slate, e.g. "20260615-1" (day + block).
    static func slateID(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day, .hour], from: date)
        let block = (c.hour ?? 0) / hoursPerBlock
        return String(format: "%04d%02d%02d-%d", c.year ?? 0, c.month ?? 0, c.day ?? 0, block)
    }

    /// Seed combining the device base and the slate id.
    static func seed(for slateID: String) -> UInt64 { deviceBase ^ fnv1a(slateID) }

    private static func fnv1a(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h == 0 ? 0x9E3779B97F4A7C15 : h
    }
}
