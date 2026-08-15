import Foundation

struct SomaAPI {
    enum APIError: LocalizedError {
        case invalidResponse
        case emptyCatalog

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "SomaFM returned an invalid response."
            case .emptyCatalog: "SomaFM returned no playable stations."
            }
        }
    }

    private struct ChannelList: Decodable {
        let channels: [Channel]

        private enum CodingKeys: CodingKey {
            case channels
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            channels = try container.decode([LossyDecodable<Channel>].self, forKey: .channels).compactMap(\.value)
        }
    }

    static let channelsURL = URL(string: "https://api.somafm.com/channels.json")!

    func loadChannels() async throws -> [Channel] {
        let (data, response) = try await URLSession.shared.data(from: Self.channelsURL)

        guard let response = response as? HTTPURLResponse, (200 ..< 300).contains(response.statusCode) else {
            throw APIError.invalidResponse
        }

        let channels = try Self.decodeChannels(from: data).filter { $0.bestQualityPlaylist != nil }
        guard !channels.isEmpty else { throw APIError.emptyCatalog }
        return channels
    }

    func loadCachedChannels() -> [Channel]? {
        let currentURL = Self.cacheURL

        for url in [currentURL, Self.legacyCacheURL].compactMap(\.self) {
            guard let data = try? Data(contentsOf: url),
                  let channels = try? Self.decodeChannels(from: data).filter({ $0.bestQualityPlaylist != nil }),
                  !channels.isEmpty else { continue }

            if url != currentURL {
                try? saveCachedChannels(channels)
            }
            return channels
        }

        return nil
    }

    func saveCachedChannels(_ channels: [Channel]) throws {
        guard let url = Self.cacheURL else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(channels).write(to: url, options: .atomic)
    }

    static func decodeChannels(from data: Data) throws -> [Channel] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode(ChannelList.self, from: data) {
            return list.channels
        }
        return try decoder.decode([LossyDecodable<Channel>].self, from: data).compactMap(\.value)
    }

    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "SomaFM", isDirectory: true)
            .appendingPathComponent("somafm_channels.json")
    }

    private static var legacyCacheURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("somafm_channels.json")
    }
}
