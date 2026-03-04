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

        // Default position: top-left, clear of the SC2 command card.
        // Height is flexible — SwiftUI content drives the size via .intrinsicContentSize.
        let width: CGFloat  = 320
        let height: CGFloat = 220
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

        // Use a high window level so the overlay appears above SC2 in
        // windowed-fullscreen / borderless mode. .screenSaver is the
        // highest standard level and reliably sits above game windows.
        win.level              = .init(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        win.isOpaque           = false
        win.backgroundColor    = .clear
        win.hasShadow          = false
        win.ignoresMouseEvents = true   // fully click-through — SC2 gets all input
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView:
            OverlayView()
                .environmentObject(gameState)
                .environmentObject(tracker)
        )
        // Let SwiftUI size the hosting view to fit its content.
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        win.contentView = hostingView
        win.orderFrontRegardless()

        self.window = win
    }

    func setVisible(_ visible: Bool) {
        if visible { window?.orderFrontRegardless() }
        else       { window?.orderOut(nil) }
    }
}
