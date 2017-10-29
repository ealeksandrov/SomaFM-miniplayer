//
//  RadioPlayer.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import AVFoundation

extension Notification.Name {
    static let radioPlayerTrackNameUpdated = Notification.Name("RadioPlayer.TrackName.Updated")
    static let radioPlayerStateUpdated = Notification.Name("RadioPlayer.State.Updated")
}

struct RadioPlayer {
    static var player: AVPlayer = {
        $0.volume = Settings.volume
        timeControlStatusToken = $0.observe(\.timeControlStatus) { _, _ in
            NotificationCenter.default.post(name: .radioPlayerStateUpdated, object: nil)
        }

        return $0
    }(AVPlayer())

    static var currentTrack: String? {
        didSet {
            NotificationCenter.default.post(name: .radioPlayerTrackNameUpdated, object: nil)
        }
    }

    private static var metadataToken: NSKeyValueObservation?
    private static var timeControlStatusToken: NSKeyValueObservation?

    static func play(channel: Channel) {
        Settings.lastPlayedChannelId = channel.id

        if let firstPlaylist = channel.bestQualityPlaylist {
            let playerItem = AVPlayerItem(url: firstPlaylist.url)
            currentTrack = nil

            metadataToken = playerItem.observe(\.timedMetadata) { item, _ in
                if let metadata = item.timedMetadata?.first {
                    currentTrack = metadata.stringValue
                }
            }

            player.replaceCurrentItem(with: playerItem)
            player.play()
        }
    }
}
