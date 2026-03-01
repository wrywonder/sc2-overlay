import Foundation

/// Decodes SALT (StarCraft Action List Timestamp) encoded build orders.
///
/// SALT strings have the form `$title|author|description|~<encoded_data>` where
/// `<encoded_data>` is a sequence of 5-character chunks.  Each chunk encodes
/// one build step: [supply, minute, second, step_type, item_code].
///
/// Characters are mapped to indices 0-94 in printable-ASCII order (space … tilde).
enum SALTDecoder {

    // MARK: - Public

    /// Returns `true` when the string looks like a SALT-encoded build order.
    static func isSALT(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("~") && trimmed.hasPrefix("$")
    }

    /// Decodes a SALT string into an array of ``BuildStep`` values.
    static func decode(_ salt: String) -> [BuildStep] {
        let trimmed = salt.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "~", maxSplits: 1)
        guard parts.count == 2 else { return [] }

        let encoded = String(parts[1])
        let chars = Array(encoded)
        var steps: [BuildStep] = []

        var i = 0
        while i + 4 < chars.count {
            let supplyIdx  = charIndex(chars[i])
            let minuteIdx  = charIndex(chars[i + 1])
            let secondIdx  = charIndex(chars[i + 2])
            let typeIdx    = charIndex(chars[i + 3])
            let codeIdx    = charIndex(chars[i + 4])

            let supply: Int? = supplyIdx > 0 ? supplyIdx + minimumSupply - 1 : nil
            let time   = TimeInterval(minuteIdx * 60 + secondIdx)
            let name   = itemName(type: typeIdx, code: codeIdx)

            steps.append(BuildStep(supply: supply, time: time, action: name))
            i += 5
        }

        return steps
    }

    // MARK: - Character set

    /// The 95 printable ASCII characters, space (0x20) through tilde (0x7E).
    private static let characters: [Character] = Array(
        " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    )

    private static let charToIndex: [Character: Int] = {
        var map: [Character: Int] = [:]
        for (i, ch) in characters.enumerated() { map[ch] = i }
        return map
    }()

    private static func charIndex(_ ch: Character) -> Int {
        charToIndex[ch] ?? 0
    }

    private static let minimumSupply = 5

    // MARK: - Name lookup

    private static func itemName(type: Int, code: Int) -> String {
        switch type {
        case 0: return structures[code] ?? "Unknown Structure"
        case 1: return units[code]      ?? "Unknown Unit"
        case 2: return morphs[code]     ?? "Unknown Morph"
        case 3: return upgrades[code]   ?? "Unknown Upgrade"
        default: return "Unknown"
        }
    }

    // MARK: - Item tables

    private static let structures: [Int: String] = [
        0: "Armory", 1: "Barracks", 2: "Bunker", 3: "Command Center",
        4: "Engineering Bay", 5: "Factory", 6: "Fusion Core",
        7: "Ghost Academy", 8: "Missile Turret",
        9: "Reactor (Barracks)", 10: "Reactor (Factory)", 11: "Reactor (Starport)",
        12: "Refinery", 13: "Sensor Tower", 14: "Starport", 15: "Supply Depot",
        16: "Tech Lab (Barracks)", 17: "Tech Lab (Factory)", 18: "Tech Lab (Starport)",
        19: "Assimilator", 20: "Cybernetics Core", 21: "Dark Shrine",
        22: "Fleet Beacon", 23: "Forge", 24: "Gateway", 25: "Nexus",
        26: "Photon Canon", 27: "Pylon", 28: "Robotics Bay",
        29: "Robotics Facility", 30: "Stargate", 31: "Templar Archives",
        32: "Twilight Council", 33: "Baneling Nest", 34: "Evolution Chamber",
        35: "Extractor", 36: "Hatchery", 37: "Hydralisk Den",
        38: "Infestation Pit", 39: "Nydus Network", 40: "Roach Warren",
        41: "Spawning Pool", 42: "Spine Crawler", 43: "Spire",
        44: "Spore Crawler", 45: "Ultralisk Cavern", 46: "Creep Tumor",
    ]

    private static let units: [Int: String] = [
        0: "Banshee", 1: "Battlecruiser", 2: "Ghost", 3: "Hellion",
        4: "Marauder", 5: "Marine", 6: "Medivac", 7: "Raven",
        8: "Reaper", 9: "SCV", 10: "Siege Tank", 11: "Thor", 12: "Viking",
        14: "Carrier", 15: "Colossus", 16: "Dark Templar",
        17: "High Templar", 18: "Immortal", 19: "Mothership",
        20: "Observer", 21: "Phoenix", 22: "Probe", 23: "Sentry",
        24: "Stalker", 25: "Void Ray", 26: "Zealot", 27: "Corruptor",
        28: "Drone", 29: "Hydralisk", 30: "Mutalisk", 31: "Overlord",
        32: "Queen", 33: "Roach", 34: "Ultralisk", 35: "Zergling",
        38: "Infestor", 39: "Warp Prism", 40: "Battle Hellion",
        41: "Warhound", 42: "Widow Mine", 43: "Mothership Core",
        44: "Oracle", 45: "Tempest", 46: "Swarm Host", 47: "Viper",
        48: "Cyclone", 49: "Liberator", 50: "Disruptor", 51: "Adepts",
    ]

    private static let morphs: [Int: String] = [
        0: "Orbital Command", 1: "Planetary Fortress", 2: "Warp Gate",
        3: "Lair", 4: "Hive", 5: "Greater Spire", 6: "Brood Lord",
        7: "Baneling", 8: "Overseer", 9: "Ravager", 10: "Lurker",
        12: "Lurker Den", 13: "Archon",
    ]

    private static let upgrades: [Int: String] = [
        0: "Terran Building Armor", 1: "Terran Infantry Armor",
        2: "Terran Infantry Weapons", 3: "Terran Ship Plating",
        4: "Terran Ship Weapons", 5: "Terran Vehicle Plating",
        6: "Terran Vehicle Weapons", 7: "250mm Strike Cannons",
        8: "Banshee - Cloaking", 9: "Ghost - Cloaking",
        10: "Hellion - Pre-igniter", 11: "Marine - Stimpack",
        12: "Raven - Seeker Missiles", 13: "Siege Tank - Siege Tech",
        14: "Bunker - Neosteel Frame", 15: "Marauder - Concussive Shells",
        16: "Marine - Combat Shields", 17: "Reaper Speed",
        18: "Protoss Ground Armor", 19: "Protoss Ground Weapons",
        20: "Protoss Air Armor", 21: "Protoss Air Weapons",
        22: "Protoss Shields", 23: "Sentry - Hallucination",
        24: "High Templar - Psi Storm", 25: "Stalker - Blink",
        26: "Warp Gate Tech", 27: "Zealot - Charge",
        28: "Zerg Ground Carapace", 29: "Zerg Melee Weapons",
        30: "Zerg Flyer Carapace", 31: "Zerg Flyer Weapons",
        32: "Zerg Missile Weapons", 33: "Hydralisk - Grooved Spines",
        34: "Overlord - Pneumatized Carapace", 35: "Overlord - Ventral Sacs",
        36: "Roach - Glial Reconstitution", 38: "Roach - Tunneling Claws",
        40: "Ultralisk - Chitinous Plating", 41: "Zergling - Adrenal Glands",
        42: "Zergling - Metabolic Boost", 44: "Burrow",
        45: "Centrifugal Hooks", 46: "Ghost - Moebius Reactor",
        47: "Extended Thermal Lance", 49: "Neural Parasite",
        50: "Pathogen Gland", 51: "Battlecruiser - Behemoth Reactor",
        52: "Battlecruiser - Weapon Refit", 53: "Hi-Sec Auto Tracking",
        54: "Medivac - Caduceus Reactor", 55: "Raven - Corvid Reactor",
        56: "Raven - Durable Materials", 57: "Hellion - Transformation servos",
        58: "Carrier - Graviton Catapult", 59: "Observer - Gravatic Boosters",
        60: "Warp Prism - Gravatic Drive", 61: "Oracle - Bosonic Core",
        62: "Tempest - Gravity Sling",
        64: "Swarm Host - Evolve Enduring Locusts",
        65: "Hydralisk - Muscular Augments", 66: "Drilling claws",
        67: "Anion Pulse-Crystals", 68: "Flying Locusts",
        69: "Seismic Spines", 71: "Targeting Optics",
        72: "Advanced Ballistics", 73: "Resonating Glaives",
    ]
}
