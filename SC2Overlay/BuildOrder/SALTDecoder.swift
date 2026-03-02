import Foundation

/// Decodes the compact SALT encoding exported by Spawning Tool
/// ("Get SALT Encoding" button).
///
/// Format (SALT v4/v5):
///   [version_char][title|author|description|~][5-char step]…
///
/// Each 5-character step encodes:
///   0: supply  (mapped value; 0 → no supply, >0 → value + 4)
///   1: minutes
///   2: seconds
///   3: step type  (0=Structure, 1=Unit, 2=Morph, 3=Upgrade)
///   4: item ID within that type
///
/// Character alphabet (94 printable ASCII chars starting at space):
///   ` !"#$%&'()*+,-./0123456789:;<=>?@A…Z[\]^_` + `` ` `` + `a…z{|}~`
enum SALTDecoder {

    // MARK: - Character mapping

    private static let alphabet: [Character] = Array(
        " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    )

    private static let charToInt: [Character: Int] = {
        var map = [Character: Int]()
        for (idx, ch) in alphabet.enumerated() { map[ch] = idx }
        return map
    }()

    /// Minimum supply offset used by SALT (supply > 0 → supply + 4).
    private static let minimumSupply = 5

    // MARK: - Public API

    /// Attempt to decode a compact SALT string.
    /// Returns nil when the input is clearly not SALT-encoded.
    static func decode(_ text: String) -> [BuildStep]? {
        // Must contain the metadata/steps separator.
        guard let tildeIdx = text.firstIndex(of: "~") else { return nil }

        let stepsStr = String(text[text.index(after: tildeIdx)...])

        // Steps portion must be a multiple of 5 characters.
        guard !stepsStr.isEmpty, stepsStr.count % 5 == 0 else { return nil }

        var steps: [BuildStep] = []
        var i = stepsStr.startIndex

        while i < stepsStr.endIndex {
            let end = stepsStr.index(i, offsetBy: 5)
            let chars = Array(stepsStr[i..<end])

            guard let rawSupply = charToInt[chars[0]],
                  let minutes   = charToInt[chars[1]],
                  let seconds   = charToInt[chars[2]],
                  let typeVal   = charToInt[chars[3]],
                  let itemId    = charToInt[chars[4]]
            else { return nil }   // corrupt encoding

            let supply: Int?
            if rawSupply > 0 {
                supply = rawSupply + minimumSupply - 1
            } else {
                supply = nil
            }

            let time = Double(minutes) * 60 + Double(seconds)

            let action: String
            switch typeVal {
            case 0:  action = structures[itemId] ?? "Structure \(itemId)"
            case 1:  action = units[itemId]      ?? "Unit \(itemId)"
            case 2:  action = morphs[itemId]     ?? "Morph \(itemId)"
            case 3:  action = upgrades[itemId]   ?? "Upgrade \(itemId)"
            default: action = "Unknown \(typeVal):\(itemId)"
            }

            steps.append(BuildStep(supply: supply, time: time, action: action))
            i = end
        }

        return steps.isEmpty ? nil : steps
    }

    // MARK: - Item lookup tables (ported from SALT.cs / sc2-scrapbook)

    // ── Structures ─────────────────────────────────────────────

    private static let structures: [Int: String] = [
        // Terran
         0: "Armory",
         1: "Barracks",
         2: "Bunker",
         3: "Command Center",
         4: "Engineering Bay",
         5: "Factory",
         6: "Fusion Core",
         7: "Ghost Academy",
         8: "Missile Turret",
         9: "Reactor (Barracks)",
        10: "Reactor (Factory)",
        11: "Reactor (Starport)",
        12: "Refinery",
        13: "Sensor Tower",
        14: "Starport",
        15: "Supply Depot",
        16: "Tech Lab (Barracks)",
        17: "Tech Lab (Factory)",
        18: "Tech Lab (Starport)",
        // Protoss
        19: "Assimilator",
        20: "Cybernetics Core",
        21: "Dark Shrine",
        22: "Fleet Beacon",
        23: "Forge",
        24: "Gateway",
        25: "Nexus",
        26: "Photon Cannon",
        27: "Pylon",
        28: "Robotics Bay",
        29: "Robotics Facility",
        30: "Stargate",
        31: "Templar Archives",
        32: "Twilight Council",
        // Zerg
        33: "Baneling Nest",
        34: "Evolution Chamber",
        35: "Extractor",
        36: "Hatchery",
        37: "Hydralisk Den",
        38: "Infestation Pit",
        39: "Nydus Network",
        40: "Roach Warren",
        41: "Spawning Pool",
        42: "Spine Crawler",
        43: "Spire",
        44: "Spore Crawler",
        45: "Ultralisk Cavern",
        46: "Creep Tumor",
    ]

    // ── Units ──────────────────────────────────────────────────

    private static let units: [Int: String] = [
        // Terran
         0: "Banshee",
         1: "Battlecruiser",
         2: "Ghost",
         3: "Hellion",
         4: "Marauder",
         5: "Marine",
         6: "Medivac",
         7: "Raven",
         8: "Reaper",
         9: "SCV",
        10: "Siege Tank",
        11: "Thor",
        12: "Viking",
        40: "Battle Hellion",
        41: "Warhound",
        42: "Widow Mine",
        48: "Cyclone",
        49: "Liberator",
        // Protoss
        14: "Carrier",
        15: "Colossus",
        16: "Dark Templar",
        17: "High Templar",
        18: "Immortal",
        19: "Mothership",
        20: "Observer",
        21: "Phoenix",
        22: "Probe",
        23: "Sentry",
        24: "Stalker",
        25: "Void Ray",
        26: "Zealot",
        39: "Warp Prism",
        43: "Mothership Core",
        44: "Oracle",
        45: "Tempest",
        50: "Disruptor",
        51: "Adept",
        // Zerg
        27: "Corruptor",
        28: "Drone",
        29: "Hydralisk",
        30: "Mutalisk",
        31: "Overlord",
        32: "Queen",
        33: "Roach",
        34: "Ultralisk",
        35: "Zergling",
        38: "Infestor",
        46: "Swarm Host",
        47: "Viper",
    ]

    // ── Morphs ─────────────────────────────────────────────────

    private static let morphs: [Int: String] = [
        // Terran
         0: "Orbital Command",
         1: "Planetary Fortress",
        // Protoss
         2: "Warp Gate",
        13: "Archon",
        // Zerg
         3: "Lair",
         4: "Hive",
         5: "Greater Spire",
         6: "Brood Lord",
         7: "Baneling",
         8: "Overseer",
         9: "Ravager",
        10: "Lurker",
        12: "Lurker Den",
    ]

    // ── Upgrades ───────────────────────────────────────────────

    private static let upgrades: [Int: String] = [
        // Terran generic
         0: "Terran Building Armor",
         1: "Terran Infantry Armor",
         2: "Terran Infantry Weapons",
         3: "Terran Ship Plating",
         4: "Terran Ship Weapons",
         5: "Terran Vehicle Plating",
         6: "Terran Vehicle Weapons",
        // Terran unit-specific
         7: "250mm Strike Cannons",
         8: "Banshee - Cloaking",
         9: "Ghost - Cloaking",
        10: "Hellion - Pre-igniter",
        11: "Marine - Stimpack",
        12: "Raven - Seeker Missiles",
        13: "Siege Tank - Siege Tech",
        14: "Bunker - Neosteel Frame",
        15: "Marauder - Concussive Shells",
        16: "Marine - Combat Shields",
        17: "Reaper Speed",
        46: "Ghost - Moebius Reactor",
        51: "Battlecruiser - Behemoth Reactor",
        52: "Battlecruiser - Weapon Refit",
        53: "Hi-Sec Auto Tracking",
        54: "Medivac - Caduceus Reactor",
        55: "Raven - Corvid Reactor",
        56: "Raven - Durable Materials",
        57: "Hellion - Transformation Servos",
        71: "Targeting Optics",
        72: "Advanced Ballistics",
        // Protoss generic
        18: "Protoss Ground Armor",
        19: "Protoss Ground Weapons",
        20: "Protoss Air Armor",
        21: "Protoss Air Weapons",
        22: "Protoss Shields",
        // Protoss unit-specific
        23: "Sentry - Hallucination",
        24: "High Templar - Psi Storm",
        25: "Stalker - Blink",
        26: "Warp Gate Tech",
        27: "Zealot - Charge",
        47: "Extended Thermal Lance",
        58: "Carrier - Graviton Catapult",
        59: "Observer - Gravatic Boosters",
        60: "Warp Prism - Gravatic Drive",
        61: "Oracle - Bosonic Core",
        62: "Tempest - Gravity Sling",
        67: "Anion Pulse-Crystals",
        73: "Resonating Glaives",
        // Zerg generic
        28: "Zerg Ground Carapace",
        29: "Zerg Melee Weapons",
        30: "Zerg Flyer Carapace",
        31: "Zerg Flyer Weapons",
        32: "Zerg Missile Weapons",
        // Zerg unit-specific
        33: "Hydralisk - Grooved Spines",
        34: "Overlord - Pneumatized Carapace",
        35: "Overlord - Ventral Sacs",
        36: "Roach - Glial Reconstitution",
        38: "Roach - Tunneling Claws",
        40: "Ultralisk - Chitinous Plating",
        41: "Zergling - Adrenal Glands",
        42: "Zergling - Metabolic Boost",
        44: "Burrow",
        45: "Centrifugal Hooks",
        49: "Neural Parasite",
        50: "Pathogen Gland",
        64: "Swarm Host - Evolve Enduring Locusts",
        65: "Hydralisk - Muscular Augments",
        66: "Drilling Claws",
        68: "Flying Locusts",
        69: "Seismic Spines",
    ]
}
