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

        // Forward game state updates to tracker
        gameState.onUpdate = { [weak self] supply, time in
            self?.tracker.update(supply: supply, time: time)
        }

        // Reset build order progress when a new game starts
        gameState.onGameStart = { [weak self] in
            self?.tracker.reset()
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
