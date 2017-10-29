//
//  Settings.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

enum UserDefaultsKey {
    static let volume = "RadioPlayer.Volume"
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
}
