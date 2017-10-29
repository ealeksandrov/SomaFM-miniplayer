//
//  AppDelegate.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let menubarController = MenubarController()

    static let bundleId: String = Bundle.main.bundleIdentifier ?? "unknown"
    static let bundleShortVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    static let bundleVersion: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Log.info("Starting \(AppDelegate.bundleId) v\(AppDelegate.bundleShortVersion) (\(AppDelegate.bundleVersion))")

        SomaAPI.loadChannels()
    }
}
