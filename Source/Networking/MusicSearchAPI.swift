//
//  MusicSearchAPI.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

public struct MusicSearchAPI {
    static var trackSearchURL: URL?

    static func searchTrack() {
        trackSearchURL = nil

        searchItunes()
    }
}

private extension MusicSearchAPI {
    // MARK: - Networking

    struct SearchResultsList: Codable {
        let results: [SearchResult]
    }

    static func searchItunes() {
        guard let trackName = RadioPlayer.currentTrack else { return }

        var iTunesSearchURL = URLComponents(string: "https://itunes.apple.com/search")!
        iTunesSearchURL.queryItems = [URLQueryItem(name: "term", value: trackName),
                                      URLQueryItem(name: "entity", value: "song"),
                                      URLQueryItem(name: "limit", value: "1"),
                                      URLQueryItem(name: "at", value: "1000lHGx")]

        guard let finalURL = iTunesSearchURL.url else { fallbackToGoogle(); return }

        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: finalURL)

        session.dataTask(with: request) { data, _, _ in
            guard let data = data else { fallbackToGoogle(); return }

            if let channelList = try? JSONDecoder().decode(SearchResultsList.self, from: data), let resultURL = channelList.results.first?.trackViewUrl {
                trackSearchURL = resultURL
            } else {
                fallbackToGoogle()
                Log.error("iTunesSearch: error")
            }
            }.resume()
    }

    static func fallbackToGoogle() {
        guard let trackName = RadioPlayer.currentTrack?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }

        trackSearchURL = URL(string: "https://www.google.ru/search?q=" + trackName)
    }
}
