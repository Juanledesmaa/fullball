import Foundation

enum BannerType: String, Codable, Sendable {
    case standard
    case featured
}

enum PullCost: Codable, Sendable, Hashable {
    case ticket(Int)
    case gems(Int)

    private enum CodingKeys: String, CodingKey { case ticket, gems }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let n = try c.decodeIfPresent(Int.self, forKey: .ticket) { self = .ticket(n) }
        else if let n = try c.decodeIfPresent(Int.self, forKey: .gems) { self = .gems(n) }
        else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "PullCost requires a 'ticket' or 'gems' key"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ticket(let n): try c.encode(n, forKey: .ticket)
        case .gems(let n): try c.encode(n, forKey: .gems)
        }
    }

    var currency: Currency { switch self { case .ticket: return .tickets; case .gems: return .gems } }
    var amount: Int { switch self { case .ticket(let n), .gems(let n): return n } }
}

/// A gacha banner. The featured banner pins specific Icon cards as the
/// "rate-up" target resolved by the 50/50 rule.
struct Banner: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let type: BannerType
    let featuredCardIDs: [String]
    let singleCost: PullCost
    let multiCost: PullCost   // cost for a 10-pull
}
