import AppKit
import SwiftUI
import UserNotifications

@main
struct SomaFMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink()
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_: Notification) {
        UNUserNotificationCenter.current().delegate = self
        statusItemController = StatusItemController(model: model)
        announceLeftClickChange()
        Task { await model.start() }
    }

    /// The left click used to always play or pause. Existing installs are told once that it now
    /// opens the menu, and can keep the old behaviour on the spot.
    private func announceLeftClickChange() {
        guard !AppSettings.didAnnounceLeftClick else { return }
        AppSettings.didAnnounceLeftClick = true
        guard AppSettings.isUpgrade, !AppSettings.hasChosenLeftClick else { return }

        let alert = NSAlert()
        alert.messageText = "Left-clicking the icon now opens the menu"
        alert.informativeText = """
        It used to play or pause. The menu has a play/pause button, and right-click still opens it.
        You can change this any time in Settings.
        """
        alert.addButton(withTitle: "Open Menu")
        alert.addButton(withTitle: "Play or Pause")

        NSApp.activate(ignoringOtherApps: true)
        AppSettings.menuBarLeftClick = alert.runModal() == .alertSecondButtonReturn ? .playPause : .openMenu
        model.settingsDidChange()
    }

    func applicationDidBecomeActive(_: Notification) {
        Task { await model.refreshSystemSettings() }
    }

    func applicationWillTerminate(_: Notification) {
        model.shutdown()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
