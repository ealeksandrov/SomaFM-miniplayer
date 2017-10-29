//
//  SomaAPI.swift
//
//  Copyright © 2017 Evgeny Aleksandrov. All rights reserved.

import Foundation

class SomaAPI {
    static let channelsURL = URL(string: "https://api.somafm.com/channels.json")!

    static func loadChannels(completion: @escaping (ChannelList?) -> Void) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let request = URLRequest(url: SomaAPI.channelsURL)

        session.dataTask(with: request) { data, _, _ in
            if let data = data, let channelList = try? JSONDecoder().decode(ChannelList.self, from: data) {
                completion(channelList)
            } else {
                completion(nil)
            }
        }.resume()
    }
}
