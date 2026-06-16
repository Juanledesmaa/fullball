import Foundation

/// Source of randomness for the gacha engine. Injected so rolls are
/// deterministic in tests.
protocol RandomProvider: Sendable {
    /// A uniform value in [0, 1).
    mutating func nextUnit() -> Double
}

extension RandomProvider {
    /// Uniform integer in 0..<upperBound.
    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        let i = Int(nextUnit() * Double(upperBound))
        return min(i, upperBound - 1)
    }
}

/// Production RNG backed by the system generator.
struct SystemRandomProvider: RandomProvider {
    private var rng = SystemRandomNumberGenerator()
    mutating func nextUnit() -> Double { Double.random(in: 0..<1, using: &rng) }
}

/// Deterministic, seedable RNG (SplitMix64). Reproducible across runs —
/// used by the engine tests.
struct SeededRandomProvider: RandomProvider {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }

    private mutating func next64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        // Top 53 bits → uniform double in [0,1).
        Double(next64() >> 11) * (1.0 / 9007199254740992.0)
    }
}

/// A provider that replays a fixed queue of unit values, then falls back
/// to 0. Lets tests script exact roll outcomes (e.g. the 50/50 coin).
struct ScriptedRandomProvider: RandomProvider {
    private var values: [Double]
    private var index = 0
    init(_ values: [Double]) { self.values = values }

    mutating func nextUnit() -> Double {
        defer { index += 1 }
        return index < values.count ? values[index] : 0
    }
}
