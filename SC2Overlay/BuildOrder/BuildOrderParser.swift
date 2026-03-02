import Foundation

enum BuildOrderParser {
    /// Parses a Spawning Tool–style build order text.
    ///
    /// Supported input formats:
    ///   Tab-delimited:  `14\t0:14\tSCV\t13 Workers`  (4-column spawningtool table paste)
    ///   Supply-based:   `14 - Supply Depot`  or  `14: Barracks`
    ///   Time-based:     `1:30 - Scout`        or  `0:22 - SCV`
    ///   Mixed (both):   `14 / 1:10 - Supply Depot`
    ///   SALT per-line:  `SALT:14|1:10|Supply Depot` or `SALT(14|1:10|Supply Depot)`
    ///   SALT encoded:   The compact SALT encoding string from spawningtool.com
    ///   Comments:       lines starting with `#` are ignored
    static func parse(text: String) -> [BuildStep] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Detect compact SALT encoding (single block with ~ separator).
        if let steps = SALTDecoder.decode(trimmed), !steps.isEmpty {
            return steps
        }

        // Fall through to line-by-line parsing.
        return trimmed
            .components(separatedBy: .newlines)
            .compactMap { parseLine($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func parseLine(_ line: String) -> BuildStep? {
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        // Tab-delimited: "14\t0:14\tSCV\t13 Workers"
        if let step = parseTabDelimitedLine(line) { return step }
        // Mixed: "14 / 1:10 - Action"
        if let step = parseMixedLine(line) { return step }
        // SALT-encoded per-line: "SALT:14|1:10|Action"
        if let step = parseSALTLine(line) { return step }
        // Time-only: "1:30 - Action"
        if let step = parseTimeLine(line)  { return step }
        // Supply-only: "14 - Action"
        if let step = parseSupplyLine(line) { return step }

        return nil
    }

    // MARK: - Line parsers

    /// Handles tab-separated (or multi-space-separated) columns copied from
    /// the Spawning Tool web table:  supply \t time \t action [\t notes]
    private static func parseTabDelimitedLine(_ line: String) -> BuildStep? {
        let fields: [String]
        if line.contains("\t") {
            fields = line.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            // Some browsers convert tabs to runs of spaces.
            let normalized = line.replacingOccurrences(
                of: #"\s{2,}"#, with: "\t", options: .regularExpression)
            fields = normalized.components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        guard fields.count >= 3 else { return nil }

        // Column 0 = supply (skip header rows where this isn't a number)
        guard let supply = Int(fields[0]), supply >= 1, supply <= 200 else { return nil }

        // Column 1 = time in MM:SS format
        let timePattern = #"^(\d+):(\d{2})$"#
        guard let tg = regexGroups(pattern: timePattern, in: fields[1]),
              tg.count == 2 else { return nil }
        let minutes = Double(tg[0]) ?? 0
        let seconds = Double(tg[1]) ?? 0

        // Column 2 = action (columns 3+ = notes, ignored)
        let action = fields[2]
        guard !action.isEmpty else { return nil }

        return BuildStep(supply: supply, time: minutes * 60 + seconds, action: action)
    }

    private static func parseMixedLine(_ line: String) -> BuildStep? {
        // Pattern: "14 / 1:30 - Action" or "14/1:30 - Action"
        let pattern = #"^(\d{1,3})\s*/\s*(\d+):(\d{2})\s*[-:–—]\s*(.+)$"#
        guard let (groups) = regexGroups(pattern: pattern, in: line), groups.count == 4 else { return nil }

        guard let supply = Int(groups[0]), supply <= 200 else { return nil }
        let minutes = Double(groups[1]) ?? 0
        let seconds = Double(groups[2]) ?? 0
        let action  = groups[3]

        return BuildStep(supply: supply, time: minutes * 60 + seconds, action: action)
    }

    private static func parseTimeLine(_ line: String) -> BuildStep? {
        // Pattern: "1:30 - Action"
        let pattern = #"^(\d+):(\d{2})\s*[-:–—]\s*(.+)$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count == 3 else { return nil }

        let minutes = Double(groups[0]) ?? 0
        let seconds = Double(groups[1]) ?? 0
        let action  = groups[2]

        return BuildStep(time: minutes * 60 + seconds, action: action)
    }

    private static func parseSupplyLine(_ line: String) -> BuildStep? {
        // Pattern: "14 - Action" or "14: Action"
        let pattern = #"^(\d{1,3})\s*[-:–—]\s*(.+)$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count == 2 else { return nil }
        guard let supply = Int(groups[0]), supply <= 200 else { return nil }

        return BuildStep(supply: supply, action: groups[1])
    }

    private static func parseSALTLine(_ line: String) -> BuildStep? {
        // Patterns:
        //   SALT:14|1:10|Supply Depot
        //   SALT(14|1:10|Supply Depot)
        let pattern = #"^SALT(?:\s*:\s*|\()(\d{1,3})\|(\d+):(\d{2})\|(.+?)(?:\))?$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count == 4 else { return nil }
        guard let supply = Int(groups[0]), supply <= 200 else { return nil }

        let minutes = Double(groups[1]) ?? 0
        let seconds = Double(groups[2]) ?? 0
        let action = groups[3].trimmingCharacters(in: .whitespaces)
        return BuildStep(supply: supply, time: minutes * 60 + seconds, action: action)
    }

    // MARK: - Regex helper

    private static func regexGroups(pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
        else { return nil }

        var groups: [String] = []
        for i in 1..<match.numberOfRanges {
            guard let range = Range(match.range(at: i), in: string) else { continue }
            groups.append(String(string[range]))
        }
        return groups.isEmpty ? nil : groups
    }
}
