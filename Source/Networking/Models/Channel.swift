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
    let listeners: Int
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .title)
        self.dj = try container.decode(String.self, forKey: .dj)
        self.djmail = try container.decode(String.self, forKey: .djmail)
        self.genre = try container.decode(String.self, forKey: .genre)
        self.image = try container.decode(URL.self, forKey: .image)
        self.largeimage = try? container.decode(URL.self, forKey: .largeimage)
        self.xlimage = try? container.decode(URL.self, forKey: .xlimage)
        self.twitter = try container.decode(String.self, forKey: .twitter)
        self.updated = try container.decode(String.self, forKey: .updated)
        if let listenersString = try? container.decode(String.self, forKey: .listeners) {
            self.listeners = Int(listenersString) ?? 0
        } else if let listenersInt = try? container.decode(Int.self, forKey: .listeners) {
            self.listeners = listenersInt
        } else {
            self.listeners = 0
        }
        self.lastPlaying = try container.decode(String.self, forKey: .lastPlaying)

        self.playlists = try container.decode([Playlist].self, forKey: .playlists)
    }
}
