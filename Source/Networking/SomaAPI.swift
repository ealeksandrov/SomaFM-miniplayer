//
//  SomaAPI.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

public extension Notification.Name {
    static let somaApiChannelsUpdated = Notification.Name("SomaAPI.Channels.Updated")
}

public class SomaAPI {
    static var channels: [Channel]? {
        didSet {
            NotificationCenter.default.post(name: .somaApiChannelsUpdated, object: nil)
        }
    }

    static func loadChannels() {
        channels = getChannelsFromDisk()
        loadChannelsFromAPI { channels in
            guard let channels = channels else { return }
            self.channels = channels
        }
    }
}

private extension SomaAPI {
    // MARK: - Networking

    struct ChannelList: Codable {
        let channels: [Channel]
    }

    static let channelsURL = URL(string: "https://api.somafm.com/channels.json")!

    static func loadChannelsFromAPI(completion: @escaping ([Channel]?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: channelsURL)

        session.dataTask(with: request) { data, _, _ in
            if let data = data, let channelList = try? JSONDecoder().decode(ChannelList.self, from: data) {
                SomaAPI.saveChannelsToDisk(channelList.channels)
                completion(channelList.channels)
            } else {
                completion(nil)
            }
            }.resume()
    }

    // MARK: - Persistence

    static func getDocumentsURL() -> URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func saveChannelsToDisk(_ channels: [Channel]?) {
        guard let channels = channels, let url = getDocumentsURL()?.appendingPathComponent("somafm_channels.json") else { return }

        do {
            let data = try JSONEncoder().encode(channels)
            try data.write(to: url, options: [])
            UserDefaults.standard.set(1, forKey: "key")
        } catch {
            print("Error saving channels to disk")
        }
    }

    static func getChannelsFromDisk() -> [Channel]? {
        guard let url = getDocumentsURL()?.appendingPathComponent("somafm_channels.json") else { return nil }

        if let data = try? Data(contentsOf: url, options: []),
            let channels = try? JSONDecoder().decode([Channel].self, from: data) {
            return channels
        }

        return nil
    }
}
