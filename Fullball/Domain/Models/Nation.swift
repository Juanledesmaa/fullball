import Foundation

/// A fictional nation entry from the catalog (tag + display name).
struct Nation: Codable, Sendable, Identifiable, Hashable {
    let tag: String
    let name: String
    var id: String { tag }
}
