import AppKit
import Observation
import QuartzCore

@MainActor
final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var statusButton: NSButton?
    private var stationMenuItems: [NSMenuItem] = []

    init(model: AppModel) {
        self.model = model
        super.init()
        configureStatusItem()
        observeModel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        statusItem.isVisible = true
        menu.autoenablesItems = false
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("SomaFM miniplayer")
        button.setAccessibilityHelp("Left click to play or pause. Right, Control, or Option click to open the menu.")
        updateStatusItem()
    }

    private func observeModel() {
        withObservationTracking {
            updateStatusItem()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeModel()
            }
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let symbolName = model.wantsPlayback ? "pause.fill" : "play.fill"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly

        let station = model.selectedChannel?.title
        let state = stateDescription
        let details = [station, model.currentTrack].compactMap { $0 }.joined(separator: " — ")
        let value = details.isEmpty ? state : "\(state): \(details)"
        button.setAccessibilityValue(value)
        button.toolTip = [value, "Left click to play or pause", "Right click to open menu"].joined(separator: "\n")
        updateMenuStatus()
        updateMenuSelection()
    }

    private var stateDescription: String {
        if model.isLoadingChannels && model.channels.isEmpty { return "Loading stations" }
        if let catalogError = model.catalogError, model.channels.isEmpty { return catalogError }

        return switch model.playbackState {
        case .idle: "Ready"
        case .loading: "Connecting"
        case .playing: "Playing"
        case .waiting: "Waiting for stream"
        case .paused: "Paused"
        case .failed: "Playback failed"
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let opensMenu = event.type == .rightMouseUp
            || event.modifierFlags.contains(.control)
            || event.modifierFlags.contains(.option)

        if opensMenu {
            showMenu(relativeTo: sender)
        } else {
            _ = model.togglePlayback()
        }
    }

    private func showMenu(relativeTo button: NSStatusBarButton) {
        if model.channels.isEmpty && !model.isLoadingChannels {
            Task { await model.start() }
        }
        rebuildMenu()
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        statusButton = nil
        stationMenuItems.removeAll(keepingCapacity: true)

        let status = NSMenuItem()
        status.view = makeStatusView()
        menu.addItem(status)

        menu.addItem(.separator())
        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeItem.view = makeVolumeView()
        menu.addItem(volumeItem)

        if AppSettings.showsRecentStations && !model.recentChannels.isEmpty {
            menu.addItem(.separator())
            let heading = NSMenuItem(title: "Recent Stations", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            model.recentChannels.forEach { menu.addItem(stationItem(for: $0)) }
        }

        menu.addItem(.separator())
        let stationsItem = NSMenuItem(title: "All Stations", action: nil, keyEquivalent: "")
        let stationsMenu = NSMenu()
        stationsMenu.autoenablesItems = false
        if model.sortedChannels.isEmpty {
            let empty = NSMenuItem(
                title: model.isLoadingChannels ? "Loading…" : "No stations available",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            stationsMenu.addItem(empty)
        } else {
            model.sortedChannels.forEach { stationsMenu.addItem(stationItem(for: $0)) }
        }
        stationsItem.submenu = stationsMenu
        menu.addItem(stationsItem)

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Settings…", action: #selector(openSettings)))

        let quit = NSMenuItem(title: "Quit SomaFM", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        resizeCustomMenuItems()
    }

    private func makeStatusView() -> NSView {
        let status = model.currentTrack ?? stateDescription
        let button = NSButton(title: shortened(status), target: self, action: #selector(performTrackAction))
        button.font = NSFont.menuFont(ofSize: 0)
        button.isBordered = false
        button.alignment = .left
        button.cell?.lineBreakMode = .byTruncatingTail
        button.isEnabled = model.currentTrack != nil
        button.toolTip = statusToolTip(for: status)
        button.wantsLayer = true

        let width = max(224, ceil(button.intrinsicContentSize.width))
        button.frame = NSRect(x: 16, y: 0, width: width, height: 22)
        button.autoresizingMask = [.width]

        let view = NSView(frame: NSRect(x: 0, y: 0, width: width + 32, height: 22))
        view.addSubview(button)
        statusButton = button
        updateStatusButtonAccessibility(status: status)
        return view
    }

    private func makeVolumeView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 34))
        let label = NSTextField(labelWithString: "Volume")
        label.frame = NSRect(x: 14, y: 9, width: 52, height: 17)

        let slider = NSSlider(
            value: Double(model.volume),
            minValue: 0,
            maxValue: 1,
            target: self,
            action: #selector(updateVolume(_:))
        )
        slider.frame = NSRect(x: 72, y: 4, width: 154, height: 26)
        slider.autoresizingMask = [.width]
        slider.isContinuous = true
        slider.setAccessibilityLabel("Volume")

        view.addSubview(label)
        view.addSubview(slider)
        return view
    }

    private func stationItem(for channel: Channel) -> NSMenuItem {
        let item = actionItem(title: channel.title, action: #selector(selectStation(_:)))
        item.representedObject = channel.id
        item.toolTip = channel.description
        item.state = channel.id == model.selectedChannelID ? .on : .off
        stationMenuItems.append(item)
        return item
    }

    private func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func shortened(_ string: String, limit: Int = 60) -> String {
        string.count > limit ? String(string.prefix(limit - 1)) + "…" : string
    }

    private func updateMenuStatus() {
        let status = model.currentTrack ?? stateDescription
        let title = shortened(status)

        if let statusButton, statusButton.title != title {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.15
            statusButton.layer?.add(transition, forKey: "status")
            statusButton.title = title
            statusButton.superview?.frame.size.width = max(
                statusButton.superview?.frame.width ?? 0,
                ceil(statusButton.intrinsicContentSize.width) + 32
            )
        }

        statusButton?.isEnabled = model.currentTrack != nil
        statusButton?.toolTip = statusToolTip(for: status)
        updateStatusButtonAccessibility(status: status)
        resizeCustomMenuItems()
    }

    private func statusToolTip(for status: String) -> String {
        model.currentTrack == nil ? status : "\(status)\n\(AppSettings.trackAction.title)"
    }

    private func updateStatusButtonAccessibility(status: String) {
        statusButton?.setAccessibilityLabel(model.currentTrack == nil ? "Playback status" : "Current track")
        statusButton?.setAccessibilityValue(status)
        statusButton?.setAccessibilityHelp(model.currentTrack == nil ? nil : AppSettings.trackAction.title)
    }

    private func resizeCustomMenuItems() {
        let width = menu.size.width
        for item in menu.items {
            item.view?.frame.size.width = width
        }
    }

    private func updateMenuSelection() {
        for item in stationMenuItems {
            item.state = item.representedObject as? String == model.selectedChannelID ? .on : .off
        }
    }

    @objc private func selectStation(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        _ = model.selectChannel(id: id)
        updateMenuSelection()
    }

    @objc private func updateVolume(_ sender: NSSlider) {
        model.setVolume(sender.floatValue)
    }

    @objc private func performTrackAction() {
        guard let track = model.currentTrack else { return }
        menu.cancelTracking()

        switch AppSettings.trackAction {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(track, forType: .string)
        case .google, .youtube, .appleMusic:
            guard let url = AppSettings.trackAction.url(for: track) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettings() {
        guard let mainMenu = NSApp.mainMenu,
              let item = mainMenu.items
                .compactMap(\.submenu)
                .flatMap(\.items)
                .first(where: {
                    $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command)
                }),
              let action = item.action else { return }
        guard NSApp.sendAction(action, to: item.target, from: item) else { return }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.isVisible && $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
        }
    }
}
