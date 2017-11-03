//
//  PreferencesViewController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet weak var startAtLoginButton: NSButton!
    @IBOutlet weak var versionLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        startAtLoginButton.state = StartAtLogin.isEnabled ? .on : .off

        if let shortVersionString: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let buildVersionString: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            versionLabel.stringValue = "Version \(shortVersionString) (\(buildVersionString))"
        }
    }

    @IBAction func tapStartAtLogin(_ sender: NSButton) {
        StartAtLogin.isEnabled = sender.state == .on
    }

    @IBAction func updateSortOrder(_ sender: NSPopUpButton) {
        NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
    }
}
