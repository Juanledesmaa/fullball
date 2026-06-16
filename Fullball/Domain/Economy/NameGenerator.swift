import Foundation

/// Generates a stable, fictional, faintly ridiculous footballer name from a
/// card id — deterministic, so a card always has the same name. Keeps the
/// no-real-likeness rule: these are invented, punny, family-friendly names.
enum NameGenerator {
    static let firsts = [
        "Reginald", "Bartholomew", "Günther", "Hans", "Pablo", "Mateo", "Kingsley",
        "Chad", "Brick", "Lance", "Duncan", "Wesley", "Sven", "Dimitri", "Kazuki",
        "Bjørn", "Mohammed", "Diego", "Thiago", "Sir", "Big", "Lil", "Turbo",
        "Cheeky", "Boomer", "Zippy", "Magic", "Sneaky", "Bonkers", "Tank", "Rooster",
        "Sunday", "Tuesday", "Goose", "Pickles", "Biscuit", "Maximus", "Wilhelm", "Yusuf",
    ]
    static let lasts = [
        "McTackle", "Nutmegger", "Goalsworth", "Ballington", "Offsider", "Toepoke",
        "Crossbar", "Bicyclekick", "Sprintwell", "Dinkworth", "Bootsworth", "Megsley",
        "Topbins", "Headerson", "Slidetackle", "Wingback", "Studsley", "Screamer",
        "Wobblefoot", "Panenka", "Chestbump", "Longball", "Hattrick", "Keepyuppy",
        "Backheel", "Throwinski", "Cleansheet", "Rabona", "Stepover", "Volleyman",
        "Postsmasher", "Onionbag", "Parkthebus", "Hoofington", "Sombrero", "Bananakick",
        "Dummyrun", "Goalhanger", "Tikitaka", "Worldie",
    ]
    static let nicks = [
        "The Wall", "Goal Machine", "The Octopus", "Lightning", "The Fridge",
        "Houdini", "The Surgeon", "Mr. Saturday", "The Vacuum", "Captain Chaos",
        "The Magnet", "Sticky Boots", "The Professor", "Two-Touch", "The Comet",
        "Iron Shins", "The Whisperer", "El Gato", "The Hammer", "Sir Slides-a-Lot",
    ]

    static func funnyName(for id: String) -> String {
        var rng = SeededRandomProvider(seed: hash(id))
        let first = firsts[rng.nextInt(firsts.count)]
        let last = lasts[rng.nextInt(lasts.count)]
        // ~1 in 4 carries a nickname.
        if rng.nextInt(4) == 0 {
            return "\(first) '\(nicks[rng.nextInt(nicks.count)])' \(last)"
        }
        return "\(first) \(last)"
    }

    private static func hash(_ s: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h == 0 ? 0x9E3779B97F4A7C15 : h
    }
}

extension Player {
    /// Memorable, fictional display name (e.g. "Turbo Nutmegger").
    var funnyName: String { NameGenerator.funnyName(for: id) }
}

extension Card {
    var funnyName: String { player.funnyName }
}
