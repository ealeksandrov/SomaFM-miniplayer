//
//  MenubarController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

class MenubarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    let rightClickMenu = NSMenu()
    let stationsMenu = NSMenu()

    init() {
        statusItem.title = "SomaFM ►"
        statusItem.toolTip = "Click to play/pause\nRight click to show menu"

        setupMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updateStationsMenu), name: .somaApiChannelsUpdated, object: nil)
    }

    func setupMenu() {
        let stationsItem = NSMenuItem(title: "Stations", action: nil, keyEquivalent: "")
        stationsItem.submenu = stationsMenu
        rightClickMenu.addItem(stationsItem)
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "Quit SomaFM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = rightClickMenu

        updateStationsMenu()
    }

    @objc func updateStationsMenu() {
        stationsMenu.removeAllItems()

        guard let channels = SomaAPI.channels, channels.count > 0 else {
            stationsMenu.addItem(NSMenuItem(title: "No channels available", action: nil, keyEquivalent: ""))
            return
        }

        for (index, channel) in channels.enumerated() {
            let channelItem = NSMenuItem(title: channel.title, action: #selector(MenubarController.selectStation(_:)), keyEquivalent: "")
            channelItem.tag = index
            channelItem.target = self
            stationsMenu.addItem(channelItem)
        }
    }

    @objc func selectStation(_ sender: NSMenuItem) {
        guard let channels = SomaAPI.channels, channels.count > sender.tag else { return }

        stationsMenu.items.forEach { $0.state = .off }
        sender.state = .on

        let channel = channels[sender.tag]
        Log.info("Selected station \"\(channel.title)\"")
    }
}
