//
//  MenubarController.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Cocoa

class MenubarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    let rightClickMenu = NSMenu()
    let stationsMenu = NSMenu()

    let trackItem = NSMenuItem(title: "Track", action: nil, keyEquivalent: "")

    init() {
        setupStatusItem()
        setupMenu()

        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updateStationsMenu), name: .somaApiChannelsUpdated, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MenubarController.updateTrackName), name: .radioPlayerTrackNameUpdated, object: nil)
    }

    func setupStatusItem() {
        statusItem.highlightMode = false

        statusItem.button?.target = self
        statusItem.button?.action = #selector(MenubarController.toggleStatus(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setStatusItem(playing: false)
    }

    func setupMenu() {
        rightClickMenu.addItem(trackItem)

        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeItem.view = setupVolumeSlider()
        rightClickMenu.addItem(volumeItem)

        let stationsItem = NSMenuItem(title: "Stations", action: nil, keyEquivalent: "")
        stationsItem.submenu = stationsMenu
        rightClickMenu.addItem(stationsItem)
        rightClickMenu.addItem(NSMenuItem.separator())
        rightClickMenu.addItem(NSMenuItem(title: "Quit SomaFM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        updateStationsMenu()
    }

    func setupVolumeSlider() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        container.autoresizingMask = [.width]
        let slider = NSSlider(frame: NSRect(x: 10, y: 0, width: 80, height: 30))
        slider.autoresizingMask = [.width, .height]
        slider.target = self
        slider.action = #selector(MenubarController.updateVolume(_:))
        slider.floatValue = Settings.volume

        container.addSubview(slider)

        return container
    }

    // MARK: - Actions

    @objc func toggleStatus(_ sender: NSStatusBarButton) {
        guard let event = NSApplication.shared.currentEvent else { return }

        if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) || event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePlay()
        }
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

    @objc func updateTrackName() {
        trackItem.title = RadioPlayer.currentTrack ?? "..."
    }

    @objc func selectStation(_ sender: NSMenuItem) {
        guard let channels = SomaAPI.channels, channels.count > sender.tag else { return }

        stationsMenu.items.forEach { $0.state = .off }
        sender.state = .on

        let channel = channels[sender.tag]
        RadioPlayer.play(channel: channel)
        Log.info("Selected station \"\(channel.title)\"")
    }

    @objc func updateVolume(_ sender: NSSlider) {
        RadioPlayer.player.volume = sender.floatValue

        if sender.window?.currentEvent?.type == .leftMouseUp {
            Settings.volume = sender.floatValue
        }
    }

    // MARK: - Private

    func showMenu() {
        statusItem.popUpMenu(rightClickMenu)
    }

    func togglePlay() {
        if RadioPlayer.player.timeControlStatus == .paused && RadioPlayer.player.currentItem != nil {
            RadioPlayer.player.play()
        } else {
            RadioPlayer.player.pause()
        }
    }

    func setStatusItem(playing: Bool) {
        if playing {
            statusItem.button?.image = NSImage(named: NSImage.Name(rawValue: "media_pause"))
            statusItem.toolTip = "Click to pause\nRight click to show menu"
        } else {
            statusItem.button?.image = NSImage(named: NSImage.Name(rawValue: "media_play"))
            statusItem.toolTip = "Click to play\nRight click to show menu"
        }
    }
}
