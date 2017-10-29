//
//  AppDelegate.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa
import MediaKeyTap

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, MediaKeyTapDelegate {

    let menubarController = MenubarController()
    var mediaKeyTap: MediaKeyTap?

    private var prefsWindowController: NSWindowController?
    var preferencesWindowController: NSWindowController? {
        if prefsWindowController == nil {
            let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
            prefsWindowController = storyboard.instantiateController(withIdentifier:
                NSStoryboard.SceneIdentifier(rawValue: "PreferencesWindow")) as? NSWindowController
        }
        return prefsWindowController
    }

    static let bundleId: String = Bundle.main.bundleIdentifier ?? "unknown"
    static let bundleShortVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    static let bundleVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Log.info("Starting \(AppDelegate.bundleId) v\(AppDelegate.bundleShortVersion) (\(AppDelegate.bundleVersion))")

        UserDefaults.standard.register(defaults: ["RadioPlayer.NotificationsEnabled": true])

        mediaKeyTap = MediaKeyTap(delegate: self)
        mediaKeyTap?.start()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        prefsWindowController = nil
    }

    // MARK: - NSWindowDelegate

    func handle(mediaKey: MediaKey, event: KeyEvent) {
        switch mediaKey {
        case .playPause:
            menubarController.togglePlay()
        case .previous, .rewind:
            menubarController.previousTap()
        case .next, .fastForward:
            menubarController.nextTap()
        }
    }
}
