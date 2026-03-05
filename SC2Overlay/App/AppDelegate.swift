import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let gameState = GameStateViewModel()
    let tracker = BuildOrderTracker()

    private var statusItem: NSStatusItem?
    private var overlayManager: OverlayWindowManager?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hide from dock

        setupMenuBar()
        overlayManager = OverlayWindowManager(gameState: gameState, tracker: tracker)

        // Share the session logger so tracker can write to the same log file.
        tracker.logger = gameState.logger

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
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "SC2 Overlay — Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 440, height: 520))
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Lightweight per-game-session file logger.
/// No console output while playing.
final class SessionLogger {
    private let directoryURL: URL
    private var fileHandle: FileHandle?
    private let iso = ISO8601DateFormatter()

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
        guard let handle = fileHandle else { return }
        let line = "[\(iso.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Intentionally swallow to avoid impacting gameplay.
        }
    }

    func endSession() {
        append("Session ended")
        try? fileHandle?.close()
        fileHandle = nil
    }
}
