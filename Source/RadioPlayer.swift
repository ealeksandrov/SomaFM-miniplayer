//
//  RadioPlayer.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import AVFoundation

extension Notification.Name {
    static let radioPlayerTrackNameUpdated = Notification.Name("RadioPlayer.TrackName.Updated")
}

struct RadioPlayer {
    static var player = AVPlayer()
    static var currentTrack: String? {
        didSet {
            NotificationCenter.default.post(name: .radioPlayerTrackNameUpdated, object: nil)
        }
    }

    private static var token: NSKeyValueObservation?

    static func play(channel: Channel) {
        if let firstPlaylist = channel.bestQualityPlaylist {
            let playerItem = AVPlayerItem(url: firstPlaylist.url)
            currentTrack = nil

            token = playerItem.observe(\.timedMetadata) { item, _ in
                if let metadata = item.timedMetadata?.first {
                    currentTrack = metadata.stringValue
                }
            }

            player.replaceCurrentItem(with: playerItem)
            player.volume = 0.1
            player.play()
        }
    }
}
