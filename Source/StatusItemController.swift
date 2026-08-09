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
    private var pulseTask: Task<Void, Never>?
    private var pulsePhase: CGFloat = 0

    private static let glyphName = "menubar-signal"

    init(model: AppModel) {
        self.model = model
        super.init()
        configureStatusItem()
        observeModel()
    }
}

private extension StatusItemController {
    func configureStatusItem() {
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

    func observeModel() {
        withObservationTracking {
            updateStatusItem()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                observeModel()
            }
        }
    }

    func updateStatusItem() {
        guard let button = statusItem.button else { return }
        applyStatusItemImage()
        button.imagePosition = .imageOnly

        let station = model.selectedChannel?.title
        let state = stateDescription
        let details = [station, model.currentTrack].compactMap(\.self).joined(separator: " — ")
        let value = details.isEmpty ? state : "\(state): \(details)"
        button.setAccessibilityValue(value)
        button.toolTip = [value, "Left click to play or pause", "Right click to open menu"].joined(separator: "\n")
        updateMenuStatus()
        updateMenuSelection()
    }

    func applyStatusItemImage() {
        statusItem.button?.image = statusItemImage
        syncPulse()
    }

    var statusItemImage: NSImage? {
        switch model.playbackState {
        case .loading, .waiting: pulseImage(phase: pulsePhase)
        case .playing: statusItemImage(opacity: 1)
        case .idle, .paused, .failed: statusItemImage(opacity: 0.6)
        }
    }

    func statusItemImage(opacity: CGFloat) -> NSImage? {
        guard let artwork = NSImage(named: Self.glyphName) else { return nil }
        return templateImage(size: artwork.size) { rect in
            artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
        }
    }

    /// Base glyph with a band of full-strength artwork travelling from the centre outwards,
    /// so the waves fill and empty in one continuous sweep. The core stays lit throughout.
    func pulseImage(phase: CGFloat) -> NSImage? {
        guard let artwork = NSImage(named: Self.glyphName) else { return nil }
        return templateImage(size: artwork.size) { rect in
            artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.5)
            guard let context = NSGraphicsContext.current else { return }
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let front = 0.05 + phase * 1.3
            let trailing = max(0, front - 0.45)
            let crest = max(min(1, front), trailing + 0.001)
            let leading = max(min(1, front + 0.45), crest + 0.001)
            let wave = NSGradient(colorsAndLocations: (.clear, trailing), (.white, crest), (.clear, leading))
            context.saveGraphicsState()
            context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
            artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            context.cgContext.setBlendMode(.destinationIn)
            wave?.draw(fromCenter: center, radius: 0, toCenter: center, radius: rect.width * 0.7, options: [])
            context.cgContext.endTransparencyLayer()
            context.restoreGraphicsState()

            let core = rect.width * 0.13
            context.saveGraphicsState()
            NSBezierPath(ovalIn: NSRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2))
                .addClip()
            artwork.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            context.restoreGraphicsState()
        }
    }

    func templateImage(size: NSSize, draw: @escaping (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            draw(rect)
            return true
        }
        image.isTemplate = true
        return image
    }

    var pulses: Bool {
        switch model.playbackState {
        case .loading, .waiting: true
        case .idle, .playing, .paused, .failed: false
        }
    }

    func syncPulse() {
        guard pulses else {
            pulseTask?.cancel()
            pulseTask = nil
            pulsePhase = 0
            return
        }
        guard pulseTask == nil else { return }
        pulseTask = Task { [weak self] in
            while true {
                guard await (try? Task.sleep(for: .milliseconds(40))) != nil, let self else { return }
                guard !Task.isCancelled, pulses else { return }
                pulsePhase = pulsePhase >= 1 ? 0 : pulsePhase + 0.04
                statusItem.button?.image = pulseImage(phase: pulsePhase)
            }
        }
    }

    var stateDescription: String {
        if model.isLoadingChannels, model.channels.isEmpty {
            return "Loading stations"
        }
        if let catalogError = model.catalogError, model.channels.isEmpty {
            return catalogError
        }

        return switch model.playbackState {
        case .idle: "Ready"
        case .loading: "Connecting"
        case .playing: "Playing"
        case .waiting: "Waiting for stream"
        case .paused: "Paused"
        case .failed: "Playback failed"
        }
    }

    @objc func handleStatusItemClick(_ sender: NSStatusBarButton) {
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

    func showMenu(relativeTo button: NSStatusBarButton) {
        if model.channels.isEmpty, !model.isLoadingChannels {
            Task { await model.start() }
        }
        rebuildMenu()
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    func rebuildMenu() {
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

        if AppSettings.showsRecentStations, !model.recentChannels.isEmpty {
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

    func makeStatusView() -> NSView {
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

    func makeVolumeView() -> NSView {
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

    func stationItem(for channel: Channel) -> NSMenuItem {
        let item = actionItem(title: channel.title, action: #selector(selectStation(_:)))
        item.representedObject = channel.id
        item.toolTip = channel.description
        item.state = channel.id == model.selectedChannelID ? .on : .off
        stationMenuItems.append(item)
        return item
    }

    func actionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func shortened(_ string: String, limit: Int = 60) -> String {
        string.count > limit ? String(string.prefix(limit - 1)) + "…" : string
    }

    func updateMenuStatus() {
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

    func statusToolTip(for status: String) -> String {
        model.currentTrack == nil ? status : "\(status)\n\(AppSettings.trackAction.title)"
    }

    func updateStatusButtonAccessibility(status: String) {
        statusButton?.setAccessibilityLabel(model.currentTrack == nil ? "Playback status" : "Current track")
        statusButton?.setAccessibilityValue(status)
        statusButton?.setAccessibilityHelp(model.currentTrack == nil ? nil : AppSettings.trackAction.title)
    }

    func resizeCustomMenuItems() {
        let width = menu.size.width
        for item in menu.items {
            item.view?.frame.size.width = width
        }
    }

    func updateMenuSelection() {
        for item in stationMenuItems {
            item.state = item.representedObject as? String == model.selectedChannelID ? .on : .off
        }
    }

    @objc func selectStation(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        _ = model.selectChannel(id: id)
        updateMenuSelection()
    }

    @objc func updateVolume(_ sender: NSSlider) {
        model.setVolume(sender.floatValue)
    }

    @objc func performTrackAction() {
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

    @objc func openSettings() {
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
