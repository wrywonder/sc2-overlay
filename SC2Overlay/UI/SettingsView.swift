import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var gameState: GameStateViewModel
    @EnvironmentObject var tracker: BuildOrderTracker

    @AppStorage("buildOrderText") private var buildOrderText: String = ""
    @State private var portText: String = "6119"
    @State private var showParseResult: Bool = false
    @State private var parsedCount: Int = 0

    var body: some View {
        Form {
            // MARK: Build Order Input
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste your Spawning Tool build order below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Supported formats:")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("  Table:   14  0:14  SCV  (copy from Spawning Tool)\n  Supply:  14 - Supply Depot\n  Time:    1:30 - Scout\n  Mixed:   14 / 1:10 - Supply Depot\n  SALT:    Paste compact encoding from Spawning Tool")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    TextEditor(text: $buildOrderText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.separator, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    HStack {
                        Button("Load Build Order") {
                            tracker.load(text: buildOrderText)
                            parsedCount = tracker.steps.count
                            showParseResult = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(buildOrderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if showParseResult {
                            Label("\(parsedCount) steps loaded", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }

                        Spacer()

                        Button("Reset") {
                            tracker.reset()
                        }
                        .foregroundStyle(.orange)

                        Button("Clear") {
                            tracker.clear()
                            buildOrderText = ""
                            showParseResult = false
                        }
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Build Order")
            }

            // MARK: Tracking Mode
            Section {
                Picker("Tracking mode", selection: $tracker.trackingMode) {
                    ForEach(TrackingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch tracker.trackingMode {
                    case .supply:
                        Text("Steps advance when your supply count reaches each threshold.")
                    case .time:
                        Text("Steps advance based on elapsed game time (mm:ss).")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Tracking")
            }

            // MARK: SC2 API
            Section {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("6119", text: $portText)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { applyPort() }
                }

                HStack {
                    Circle()
                        .fill(gameState.isInGame ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(gameState.connectionStatus.rawValue)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } header: {
                Text("SC2 Client API")
            } footer: {
                Text("Add `gameClientRequestPort=6119` to your Variables.txt, or launch SC2 with `-gameClientRequestPort 6119`.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // MARK: Loaded steps preview
            if !tracker.steps.isEmpty {
                Section {
                    List(tracker.steps) { step in
                        HStack(spacing: 8) {
                            if let s = step.supply {
                                Text("\(s)")
                                    .frame(width: 28, alignment: .trailing)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.orange)
                            }
                            if let t = step.time {
                                Text(formatTime(t))
                                    .frame(width: 40, alignment: .trailing)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.blue)
                            }
                            Text(step.action)
                                .font(.system(size: 12))
                        }
                    }
                    .frame(height: 140)
                } header: {
                    Text("Loaded steps (\(tracker.steps.count))")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .padding()
        .onAppear { portText = "\(gameState.port)" }
    }

    private func applyPort() {
        guard let p = Int(portText), (1...65535).contains(p) else { return }
        gameState.port = p
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
