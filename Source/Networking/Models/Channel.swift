//
//  Channel.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

public struct Channel: Codable {
    let id: String
    let title: String
    let description: String
    let dj: String
    let djmail: String
    let genre: String
    let image: URL
    let largeimage: URL?
    let xlimage: URL?
    let twitter: String
    let updated: String
    let listeners: String
    let lastPlaying: String

    let playlists: [Playlist]

    var bestQualityPlaylist: Playlist? {
        if let playlist = playlists.filter({ $0.quality == .highest && $0.format == .aac }).first {
            return playlist
        } else if let playlist = playlists.filter({ $0.quality == .highest }).first {
            return playlist
        } else if let playlist = playlists.filter({ $0.quality == .high }).first {
            return playlist
        } else if let playlist = playlists.first {
            return playlist
        } else {
            return nil
        }
    }
}
