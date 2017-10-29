//
//  Settings.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

enum UserDefaultsKey {
    static let volume = "RadioPlayer.Volume"
    static let lastPlayedChannel = "RadioPlayer.Channel.LastPlayed"
    static let shouldPlayOnLaunch = "RadioPlayer.ShouldPlayOnLaunch"
    static let apiCacheTimestamp = "SomaAPI.Cache.Timestamp"
}

struct Settings {
    static var volume: Float {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.volume) as? Float ?? 0.5
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.volume)
        }
    }

    static var cacheTimestamp: Date? {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.apiCacheTimestamp) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.apiCacheTimestamp)
        }
    }

    static var lastPlayedChannelId: String {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.lastPlayedChannel) as? String ?? "groovesalad"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.lastPlayedChannel)
        }
    }

    static var shouldPlayOnLaunch: Bool {
        get {
            return UserDefaults.standard.object(forKey: UserDefaultsKey.shouldPlayOnLaunch) as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKey.shouldPlayOnLaunch)
        }
    }
}
