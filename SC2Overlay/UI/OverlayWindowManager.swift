import AppKit
import SwiftUI

class OverlayWindowManager {
    private var window: NSWindow?
    private let gameState: GameStateViewModel
    private let tracker: BuildOrderTracker
    private let logger: SessionLogger
    private var keepOnTopTimer: Timer?

    init(gameState: GameStateViewModel, tracker: BuildOrderTracker, logger: SessionLogger) {
        self.gameState = gameState
        self.tracker   = tracker
        self.logger    = logger
        createWindow()
        startKeepOnTopTimer()
    }

    private func createWindow() {
        guard let screen = NSScreen.main else {
            logger.append("OverlayWindow: NSScreen.main is nil — cannot create window")
            return
        }

        // Default position: top-left, clear of the SC2 command card
        let width: CGFloat  = 320
        let height: CGFloat = 110
        let margin: CGFloat = 20
        let frame = CGRect(
            x: margin,
            y: screen.visibleFrame.maxY - height - margin,
            width: width,
            height: height
        )

        let win = NSWindow(
            contentRect: frame,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       false
        )

        // Use screenSaver level (1000) to sit above fullscreen apps / Game Mode.
        // .floating (3) is too low — macOS fullscreen spaces render above it.
        win.level              = NSWindow.Level(rawValue:
            Int(CGWindowLevelForKey(.screenSaverWindow)))
        win.isOpaque           = false
        win.backgroundColor    = .clear
        win.hasShadow          = false
        win.ignoresMouseEvents = true   // fully click-through — SC2 gets all input
        win.collectionBehavior = [
            .canJoinAllSpaces,       // visible on every Space / fullscreen Space
            .fullScreenAuxiliary,    // allowed alongside fullscreen apps
            .stationary,             // ignored by Mission Control / Exposé
            .ignoresCycle,           // skip in Cmd-Tab
        ]

        let root = OverlayView()
            .environmentObject(gameState)
            .environmentObject(tracker)

        win.contentView = NSHostingView(rootView: root)
        win.orderFrontRegardless()

        self.window = win

        logger.append("OverlayWindow created: frame=\(win.frame)")
        logger.append("  screen=\"\(screen.localizedName)\" visibleFrame=\(screen.visibleFrame) fullFrame=\(screen.frame)")
        logger.append("  windowLevel=\(win.level.rawValue) (screenSaver=\(NSWindow.Level.screenSaver.rawValue))")
    }

    /// Periodically re-assert front ordering so the overlay survives
    /// focus grabs from SC2 or macOS window-server shuffles.
    private func startKeepOnTopTimer() {
        keepOnTopTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.window?.orderFrontRegardless()
            }
        }
    }

    func setVisible(_ visible: Bool) {
        if visible { window?.orderFrontRegardless() }
        else       { window?.orderOut(nil) }
    }

    deinit {
        keepOnTopTimer?.invalidate()
    }
}
