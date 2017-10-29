//
//  RadioPlayer.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation
import AVFoundation

struct RadioPlayer {
    static var player = AVPlayer()

    static func play(channel: Channel) {
        if let firstPlaylist = channel.bestQualityPlaylist {
            let playerItem = AVPlayerItem(url: firstPlaylist.url)
            player.replaceCurrentItem(with: playerItem)
            player.volume = 0.1
            player.play()
        }
    }
}
