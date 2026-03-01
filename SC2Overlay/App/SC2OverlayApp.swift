import SwiftUI

@main
struct SC2OverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window — opened from the menu bar
        Settings {
            SettingsView()
                .environmentObject(appDelegate.gameState)
                .environmentObject(appDelegate.tracker)
        }
    }
}
