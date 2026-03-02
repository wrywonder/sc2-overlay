import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let logger: SessionLogger
    let gameState: GameStateViewModel
    let tracker: BuildOrderTracker

    private var statusItem: NSStatusItem?
    private var overlayManager: OverlayWindowManager?
    private var settingsWindow: NSWindow?

    override init() {
        let log = SessionLogger()
        self.logger = log
        self.gameState = GameStateViewModel(logger: log)
        self.tracker = BuildOrderTracker(logger: log)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hide from dock

        setupMenuBar()
        overlayManager = OverlayWindowManager(gameState: gameState,
                                               tracker: tracker,
                                               logger: logger)

        // Forward game state updates to tracker
        gameState.onUpdate = { [weak self] supply, time in
            self?.tracker.update(supply: supply, time: time)
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill",
                                   accessibilityDescription: "SC2 Overlay")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "SC2 Overlay", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings & Build Order…",
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SC2 Overlay",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(gameState)
                .environmentObject(tracker)
                .environmentObject(logger)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "SC2 Overlay — Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 480, height: 700))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Session Logger

/// Lightweight per-game-session file logger with in-memory buffer
/// for the in-app debug log viewer.
final class SessionLogger: ObservableObject {
    private let directoryURL: URL
    private var fileHandle: FileHandle?
    private let iso = ISO8601DateFormatter()
    private let maxLines = 500

    /// Recent log lines visible in Settings → Debug Log.
    @Published var recentLines: [String] = []

    init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let base = appSupport
            .appendingPathComponent("SC2Overlay", isDirectory: true)
            .appendingPathComponent("SessionLogs", isDirectory: true)

        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        directoryURL = base
    }

    func startSession() {
        endSession()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let stamp = formatter.string(from: Date())
        let url = directoryURL.appendingPathComponent("session_\(stamp).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
        append("Session started")
    }

    func append(_ message: String) {
        let line = "[\(iso.string(from: Date()))] \(message)"

        // File logging (only when a session is active)
        if let handle = fileHandle,
           let data = (line + "\n").data(using: .utf8) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Intentionally swallow to avoid impacting gameplay.
            }
        }

        // In-memory buffer (always active)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recentLines.append(line)
            if self.recentLines.count > self.maxLines {
                self.recentLines.removeFirst(self.recentLines.count - self.maxLines)
            }
        }
    }

    func endSession() {
        if fileHandle != nil {
            append("Session ended")
            try? fileHandle?.close()
            fileHandle = nil
        }
    }
}
