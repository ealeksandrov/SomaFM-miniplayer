//
//  PreferencesViewController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

class PreferencesViewController: NSViewController {

    @IBOutlet weak var startAtLoginButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        startAtLoginButton.state = StartAtLogin.isEnabled ? .on : .off
    }

    @IBAction func tapStartAtLogin(_ sender: NSButton) {
        StartAtLogin.isEnabled = sender.state == .on
    }

    @IBAction func updateSortOrder(_ sender: NSPopUpButton) {
        NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
    }
}
