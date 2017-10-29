//
//  PreferencesViewController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

class PreferencesViewController: NSViewController {

    @IBAction func updateSortOrder(_ sender: NSPopUpButton) {
        NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
    }
}
