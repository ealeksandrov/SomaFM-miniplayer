import Foundation

enum UserDefaultsKey {
    static let volume = "RadioPlayer.Volume"
    static let lastPlayedChannel = "RadioPlayer.Channel.LastPlayed"
    static let shouldPlayOnLaunch = "RadioPlayer.ShouldPlayOnLaunch"
    static let notificationsEnabled = "RadioPlayer.NotificationsEnabled"
    static let apiCacheTimestamp = "SomaAPI.Cache.Timestamp"
    static let apiChannelsSortOrder = "SomaAPI.Channels.SortOrder"
    static let trackAction = "TrackSearch.Provider"
    static let recentChannelIDs = "SomaFM.RecentChannelIDs"
    static let showsRecentStations = "SomaFM.ShowsRecentStations"
    static let menuBarLeftClick = "SomaFM.MenuBarLeftClick"
    static let didAnnounceLeftClick = "SomaFM.DidAnnounceLeftClick"
    static let didMigrateLoginItem = "SomaFM.DidMigrateLoginItem"
    static let settingsPane = "SomaFM.SettingsPane"
}

enum AppSettings {
    static var volume: Float {
        get {
            let value = (UserDefaults.standard.object(forKey: UserDefaultsKey.volume) as? NSNumber)?.floatValue ?? 0.5
            return min(max(value, 0), 1)
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0), 1), forKey: UserDefaultsKey.volume)
        }
    }

    static var channelsSortOrder: ChannelsSortOrder {
        get {
            ChannelsSortOrder(rawValue: UserDefaults.standard.integer(forKey: UserDefaultsKey.apiChannelsSortOrder)) ??
                .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.apiChannelsSortOrder)
        }
    }

    static var lastPlayedChannelID: String {
        get { UserDefaults.standard.string(forKey: UserDefaultsKey.lastPlayedChannel) ?? "groovesalad" }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastPlayedChannel) }
    }

    static var shouldPlayOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKey.shouldPlayOnLaunch)
    }

    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKey.notificationsEnabled)
    }

    static var trackAction: TrackAction {
        TrackAction(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.trackAction) ?? "") ?? .google
    }

    static var menuBarLeftClick: MenuBarClickAction {
        get {
            MenuBarClickAction(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.menuBarLeftClick) ?? "")
                ?? .openMenu
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaultsKey.menuBarLeftClick)
        }
    }

    static var hasChosenLeftClick: Bool {
        UserDefaults.standard.string(forKey: UserDefaultsKey.menuBarLeftClick) != nil
    }

    /// A user who has played something before this build exists in defaults; a fresh install does not.
    static var isUpgrade: Bool {
        UserDefaults.standard.object(forKey: UserDefaultsKey.lastPlayedChannel) != nil
    }

    static var didAnnounceLeftClick: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKey.didAnnounceLeftClick) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.didAnnounceLeftClick) }
    }

    static var didMigrateLoginItem: Bool {
        get { UserDefaults.standard.bool(forKey: UserDefaultsKey.didMigrateLoginItem) }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.didMigrateLoginItem) }
    }

    static var recentChannelIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: UserDefaultsKey.recentChannelIDs) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.recentChannelIDs) }
    }

    static var showsRecentStations: Bool {
        UserDefaults.standard.object(forKey: UserDefaultsKey.showsRecentStations) == nil
            || UserDefaults.standard.bool(forKey: UserDefaultsKey.showsRecentStations)
    }
}
