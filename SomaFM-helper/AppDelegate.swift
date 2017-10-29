//
//  AppDelegate.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Get helper bundle id
        guard let helperBundleId = Bundle.main.bundleIdentifier, helperBundleId.hasSuffix("-helper")
            else { NSApp.terminate(nil); return }

        // Get main bundle id
        let mainAppBundleId = helperBundleId.replacingOccurrences(of: "-helper", with: "")

        // Ensure the app is not already running
        if !NSRunningApplication.runningApplications(withBundleIdentifier: mainAppBundleId).isEmpty {
            NSApp.terminate(nil); return
        }

        // Get path to main app
        let helperBundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let mainAppBundleURL = helperBundleURL .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let mainAppBundle = Bundle(url: mainAppBundleURL)

        // Launch main app
        if let binaryPath = mainAppBundle?.executablePath {
            NSWorkspace.shared.launchApplication(binaryPath)
        }

        NSApp.terminate(nil)
    }
}
