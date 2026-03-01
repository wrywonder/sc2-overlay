import AppKit
import SwiftUI

@MainActor
class OverlayWindowManager {
    private var window: NSWindow?
    private let gameState: GameStateViewModel
    private let tracker: BuildOrderTracker

    init(gameState: GameStateViewModel, tracker: BuildOrderTracker) {
        self.gameState = gameState
        self.tracker   = tracker
        createWindow()
    }

    private func createWindow() {
        guard let screen = NSScreen.main else { return }

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

        win.level              = .floating
        win.isOpaque           = false
        win.backgroundColor    = .clear
        win.hasShadow          = false
        win.ignoresMouseEvents = true   // fully click-through — SC2 gets all input
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = OverlayView()
            .environmentObject(gameState)
            .environmentObject(tracker)

        win.contentView = NSHostingView(rootView: root)
        win.orderFrontRegardless()

        self.window = win
    }

    func setVisible(_ visible: Bool) {
        if visible { window?.orderFrontRegardless() }
        else       { window?.orderOut(nil) }
    }
}
