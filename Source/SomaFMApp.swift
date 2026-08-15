import AppKit
import ServiceManagement
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
        migrateLegacyLoginItem()
        UNUserNotificationCenter.current().delegate = self
        statusItemController = StatusItemController(model: model)
        announceLeftClickChange()
        Task { await model.start() }
    }

    /// Carries 1.2.0's `SMLoginItemSetEnabled` choice over to `SMAppService.mainApp`, once and
    /// silently, so upgrading does not quietly turn auto-start off.
    ///
    /// Best effort: macOS purges the orphaned records at the next login, so this only reaches
    /// users who relaunch before rebooting.
    private func migrateLegacyLoginItem() {
        guard !AppSettings.didMigrateLoginItem else { return }

        // nil means the read failed, which is not the same as "no legacy item".
        guard let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?
            .takeRetainedValue() as? [[String: AnyObject]]
        else { return }

        let job = jobs.first { $0["Label"] as? String == Self.legacyHelperID }
        // `OnDemand` is what 1.2.0 reported, so false means the user turned it off.
        guard job?["OnDemand"] as? Bool == true else {
            AppSettings.didMigrateLoginItem = true
            return
        }

        let service = SMAppService.mainApp
        if service.status == .notRegistered || service.status == .notFound {
            do {
                try service.register()
            } catch {
                return
            }
        }

        // `.requiresApproval` is registered but not running yet, so retry instead of finishing.
        guard service.status == .enabled else { return }

        // The stale helper entry is left alone: `SMAppService` cannot resolve it once the
        // bundle is gone, and macOS drops it at the next login anyway.
        AppSettings.didMigrateLoginItem = true
    }

    private static let legacyHelperID = "com.ealeksandrov.somafm-helper"

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
