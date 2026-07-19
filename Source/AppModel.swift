import Foundation
import Observation
import OSLog
import ServiceManagement
import UserNotifications

func sortChannels(_ channels: [Channel], by order: ChannelsSortOrder) -> [Channel] {
    switch order {
    case .default:
        channels
    case .listeners:
        channels.sorted {
            $0.listeners == $1.listeners
                ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                : $0.listeners > $1.listeners
        }
    case .alphabetically:
        channels.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

func resolveChannel(in channels: [Channel], savedID: String) -> Channel? {
    channels.first { $0.id == savedID }
        ?? channels.first { $0.id == "groovesalad" }
        ?? channels.first
}

func adjacentChannel(in channels: [Channel], selectedID: String?, offset: Int) -> Channel? {
    guard !channels.isEmpty else { return nil }
    let currentIndex = channels.firstIndex { $0.id == selectedID } ?? 0
    let nextIndex = (currentIndex + offset % channels.count + channels.count) % channels.count
    return channels[nextIndex]
}

func addingRecent(_ id: String, to ids: [String], limit: Int = 5) -> [String] {
    Array(([id] + ids.filter { $0 != id }).prefix(limit))
}

func existingChannelIDs(_ ids: [String], in channels: [Channel]) -> [String] {
    let validIDs = Set(channels.map(\.id))
    return ids.filter(validIDs.contains)
}

struct PlayOnLaunchGate: Sendable {
    private var isPending: Bool

    init(enabled: Bool) {
        isPending = enabled
    }

    mutating func consume(hasChannels: Bool) -> Bool {
        guard isPending, hasChannels else { return false }
        isPending = false
        return true
    }
}

@MainActor
@Observable
final class AppModel {
    private let api = SomaAPI()
    private let player: RadioPlayer
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ealeksandrov.somafm", category: "App")
    private var playOnLaunchGate = PlayOnLaunchGate(enabled: AppSettings.shouldPlayOnLaunch)
    private var settingsRevision = 0

    private(set) var channels: [Channel] = []
    private(set) var selectedChannelID = AppSettings.lastPlayedChannelID
    private(set) var currentTrack: String?
    private(set) var playbackState: PlaybackState = .idle
    private(set) var isLoadingChannels = false
    private(set) var catalogError: String?
    private(set) var recentChannelIDs = AppSettings.recentChannelIDs
    private(set) var loginItemStatus = SMAppService.mainApp.status
    private(set) var loginItemError: String?
    private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var volume = AppSettings.volume

    var selectedChannel: Channel? {
        channels.first { $0.id == selectedChannelID }
    }

    var sortedChannels: [Channel] {
        _ = settingsRevision
        return sortChannels(channels, by: AppSettings.channelsSortOrder)
    }

    var recentChannels: [Channel] {
        recentChannelIDs.compactMap { id in channels.first { $0.id == id } }
    }

    var wantsPlayback: Bool {
        player.wantsPlayback
    }

    var loginItemMessage: String? {
        if let loginItemError { return loginItemError }

        switch loginItemStatus {
        case .enabled, .notRegistered:
            return nil
        case .requiresApproval:
            return "Allow SomaFM in System Settings > General > Login Items."
        case .notFound:
            return "macOS could not find the login item. Move SomaFM to Applications and try again."
        @unknown default:
            return "Login item status is unavailable."
        }
    }

    init() {
        player = RadioPlayer(volume: AppSettings.volume)

        player.stateChanged = { [weak self] state in
            self?.playbackState = state
        }
        player.trackChanged = { [weak self] track in
            self?.receiveTrack(track)
        }
        player.playCommand = { [weak self] in self?.playSelectedChannel() ?? false }
        player.pauseCommand = { [weak self] in self?.pause() ?? false }
        player.toggleCommand = { [weak self] in self?.togglePlayback() ?? false }
        player.previousCommand = { [weak self] in self?.selectAdjacent(offset: -1) ?? false }
        player.nextCommand = { [weak self] in self?.selectAdjacent(offset: 1) ?? false }
    }

    func start() async {
        guard !isLoadingChannels else { return }
        logger.info("Starting SomaFM miniplayer")
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.apiCacheTimestamp)
        isLoadingChannels = true

        if let cachedChannels = api.loadCachedChannels() {
            applyChannels(cachedChannels)
        }

        await refreshSystemSettings()

        do {
            let freshChannels = try await api.loadChannels()
            applyChannels(freshChannels)
            try api.saveCachedChannels(freshChannels)
            catalogError = nil
        } catch {
            logger.error("Channel refresh failed: \(error.localizedDescription, privacy: .public)")
            if channels.isEmpty {
                catalogError = error.localizedDescription
            }
        }

        isLoadingChannels = false
    }

    func shutdown() {
        player.shutdown()
    }

    @discardableResult
    func togglePlayback() -> Bool {
        if player.wantsPlayback {
            player.pause()
            return true
        }
        return playSelectedChannel()
    }

    @discardableResult
    func pause() -> Bool {
        guard player.wantsPlayback else { return false }
        player.pause()
        return true
    }

    @discardableResult
    func selectChannel(id: String) -> Bool {
        guard let channel = channels.first(where: { $0.id == id }) else { return false }
        selectedChannelID = channel.id
        AppSettings.lastPlayedChannelID = channel.id
        recentChannelIDs = addingRecent(channel.id, to: recentChannelIDs)
        AppSettings.recentChannelIDs = recentChannelIDs
        currentTrack = nil
        logger.info("Selected station \(channel.title, privacy: .public)")
        return player.play(channel)
    }

    @discardableResult
    func selectAdjacent(offset: Int) -> Bool {
        guard let channel = adjacentChannel(in: sortedChannels, selectedID: selectedChannelID, offset: offset) else {
            return false
        }
        return selectChannel(id: channel.id)
    }

    func setVolume(_ value: Float) {
        volume = min(max(value, 0), 1)
        AppSettings.volume = volume
        player.setVolume(volume)
    }

    func settingsDidChange() {
        settingsRevision &+= 1
    }

    func setStartAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        loginItemError = nil

        do {
            if enabled {
                if service.status == .notRegistered {
                    try service.register()
                } else if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            loginItemError = error.localizedDescription
        }

        loginItemStatus = service.status
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func refreshSystemSettings() async {
        loginItemStatus = SMAppService.mainApp.status
        notificationAuthorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func notificationPreferenceChanged(enabled: Bool) async {
        guard enabled else {
            await refreshNotificationStatus()
            return
        }

        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert])
        }
        await refreshNotificationStatus()
    }

    private func applyChannels(_ newChannels: [Channel]) {
        channels = newChannels

        recentChannelIDs = existingChannelIDs(recentChannelIDs, in: newChannels)
        AppSettings.recentChannelIDs = recentChannelIDs

        if let channel = resolveChannel(in: newChannels, savedID: selectedChannelID) {
            selectedChannelID = channel.id
            AppSettings.lastPlayedChannelID = channel.id
        }

        if playOnLaunchGate.consume(hasChannels: !newChannels.isEmpty) {
            _ = playSelectedChannel()
        }
    }

    private func playSelectedChannel() -> Bool {
        guard let channel = selectedChannel else { return false }
        return player.resume(channel)
    }

    private func receiveTrack(_ track: String?) {
        guard track != currentTrack else { return }
        currentTrack = track

        guard let track, AppSettings.notificationsEnabled else { return }
        Task { @MainActor [weak self] in
            await self?.deliverNotification(for: track)
        }
    }

    private func deliverNotification(for track: String) async {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus

        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert])
            status = await center.notificationSettings().authorizationStatus
        }

        notificationAuthorizationStatus = status
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = selectedChannel?.title ?? "SomaFM"
        content.body = track
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func refreshNotificationStatus() async {
        notificationAuthorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
