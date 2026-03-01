import Foundation

enum BuildOrderParser {
    /// Parses a build order from any supported format, detecting it automatically.
    ///
    /// Supported formats:
    ///   **SALT**:         `$title|author|desc|~<encoded>`  (compact sharing format)
    ///   **Tab-separated**: `14\t0:17\tSupply Depot\tNote`  (Spawning Tool export)
    ///   **Mixed**:        `14 / 1:10 - Supply Depot`
    ///   **Time-only**:    `1:30 - Scout`
    ///   **Supply-only**:  `14 - Supply Depot`  or  `14: Barracks`
    ///   **Comments**:     lines starting with `#` are ignored
    static func parse(text: String) -> [BuildStep] {
        if SALTDecoder.isSALT(text) {
            return SALTDecoder.decode(text)
        }

        return text
            .components(separatedBy: .newlines)
            .compactMap { parseLine($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func parseLine(_ line: String) -> BuildStep? {
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        // Tab-separated: "14\t0:17\tSupply Depot\tNote"
        if let step = parseTabLine(line)    { return step }
        // Mixed: "14 / 1:10 - Action"
        if let step = parseMixedLine(line)  { return step }
        // Time-only: "1:30 - Action"
        if let step = parseTimeLine(line)   { return step }
        // Supply-only: "14 - Action"
        if let step = parseSupplyLine(line) { return step }

        return nil
    }

    // MARK: - Line parsers

    private static func parseTabLine(_ line: String) -> BuildStep? {
        // Pattern: "14\t0:17\tSupply Depot\tOptional note"
        // Fields are tab-separated; note column is optional.
        guard line.contains("\t") else { return nil }
        let pattern = #"^(\d{1,3})\t\s*(\d+):(\d{2})\t\s*(.+?)(?:\t\s*(.+))?$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count >= 4 else { return nil }

        guard let supply = Int(groups[0]), supply <= 200 else { return nil }
        let minutes = Double(groups[1]) ?? 0
        let seconds = Double(groups[2]) ?? 0
        let action  = groups[3].trimmingCharacters(in: .whitespaces)
        let note    = groups.count == 5 ? groups[4].trimmingCharacters(in: .whitespaces) : nil

        return BuildStep(supply: supply, time: minutes * 60 + seconds, action: action,
                         note: note?.isEmpty == false ? note : nil)
    }

    private static func parseMixedLine(_ line: String) -> BuildStep? {
        // Pattern: "14 / 1:30 - Action" or "14/1:30 - Action"
        let pattern = #"^(\d{1,3})\s*/\s*(\d+):(\d{2})\s*[-:]\s*(.+)$"#
        guard let (groups) = regexGroups(pattern: pattern, in: line), groups.count == 4 else { return nil }

        guard let supply = Int(groups[0]), supply <= 200 else { return nil }
        let minutes = Double(groups[1]) ?? 0
        let seconds = Double(groups[2]) ?? 0
        let action  = groups[3]

        return BuildStep(supply: supply, time: minutes * 60 + seconds, action: action)
    }

    private static func parseTimeLine(_ line: String) -> BuildStep? {
        // Pattern: "1:30 - Action"
        let pattern = #"^(\d+):(\d{2})\s*[-:]\s*(.+)$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count == 3 else { return nil }

        let minutes = Double(groups[0]) ?? 0
        let seconds = Double(groups[1]) ?? 0
        let action  = groups[2]

        return BuildStep(time: minutes * 60 + seconds, action: action)
    }

    private static func parseSupplyLine(_ line: String) -> BuildStep? {
        // Pattern: "14 - Action" or "14: Action"
        let pattern = #"^(\d{1,3})\s*[-:]\s*(.+)$"#
        guard let groups = regexGroups(pattern: pattern, in: line), groups.count == 2 else { return nil }
        guard let supply = Int(groups[0]), supply <= 200 else { return nil }

        return BuildStep(supply: supply, action: groups[1])
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
