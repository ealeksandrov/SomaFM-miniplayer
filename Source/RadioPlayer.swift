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
    private static var metadataToken: NSKeyValueObservation?
    private static var timeControlStatusToken: NSKeyValueObservation?

    static var player: AVPlayer = {
        $0.volume = Settings.volume
        timeControlStatusToken = $0.observe(\.timeControlStatus) { _, _ in
            NotificationCenter.default.post(name: .radioPlayerStateUpdated, object: nil)
        }
        metadataToken = $0.observe(\.currentItem?.timedMetadata) { player, _ in
            if let metadata = player.currentItem?.timedMetadata?.first {
                currentTrack = metadata.stringValue
            }
        }
        return $0
    }(AVPlayer())

    static var currentTrack: String? {
        didSet {
            NotificationCenter.default.post(name: .radioPlayerTrackNameUpdated, object: nil)
        }
    }

    static func play(channel: Channel) {
        Settings.lastPlayedChannelId = channel.id

        if let playerItem = playerItem(fromChannel: channel) {
            player.replaceCurrentItem(with: playerItem)
            player.play()
        }
    }

    static func resumeLive() {
        if let playerItem = playerItem(fromChannel: SomaAPI.lastPlayedChannel) {
            player.replaceCurrentItem(with: playerItem)
            player.play()
        }
    }

    // MARK: - Private

    private static func playerItem(fromChannel: Channel?) -> AVPlayerItem? {
        guard let channel = fromChannel, let firstPlaylist = channel.bestQualityPlaylist else { return nil }

        let playerItem = AVPlayerItem(url: firstPlaylist.url)
        currentTrack = nil

        return playerItem
    }
}
