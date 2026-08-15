import Foundation

enum ChannelsSortOrder: Int, CaseIterable, Identifiable {
    case `default`
    case listeners
    case alphabetically

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .default: "SomaFM order"
        case .listeners: "Number of listeners"
        case .alphabetically: "Alphabetically"
        }
    }
}

enum MenuBarClickAction: String, CaseIterable, Identifiable {
    case openMenu
    case playPause

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .openMenu: "Open Menu"
        case .playPause: "Play or Pause"
        }
    }
}

enum TrackAction: String, CaseIterable, Identifiable {
    case copy
    case google
    case youtube
    case appleMusic

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .copy: "Copy Track Name"
        case .google: "Search with Google"
        case .youtube: "Search with YouTube"
        case .appleMusic: "Search with Apple Music"
        }
    }

    func url(for track: String) -> URL? {
        var components: URLComponents

        switch self {
        case .copy:
            return nil
        case .google:
            components = URLComponents(string: "https://www.google.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: track)]
        case .youtube:
            components = URLComponents(string: "https://www.youtube.com/results")!
            components.queryItems = [URLQueryItem(name: "search_query", value: track)]
        case .appleMusic:
            components = URLComponents(string: "https://music.apple.com/us/search")!
            components.queryItems = [URLQueryItem(name: "term", value: track)]
        }

        return components.url
    }
}

struct Playlist: Codable, Equatable {
    enum Format: String, Codable {
        case aac
        case aacp
        case mp3
    }

    enum Quality: String, Codable {
        case highest
        case high
        case low
    }

    let url: URL
    let format: Format
    let quality: Quality

    init(url: URL, format: Format, quality: Quality) {
        self.url = url
        self.format = format
        self.quality = quality
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let url = try container.decode(URL.self, forKey: .url)

        guard url.scheme?.lowercased() == "https" else {
            throw DecodingError.dataCorruptedError(
                forKey: .url,
                in: container,
                debugDescription: "Only HTTPS playlists are supported"
            )
        }

        self.url = url
        format = try container.decode(Format.self, forKey: .format)
        quality = try container.decode(Quality.self, forKey: .quality)
    }
}

struct Channel: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let listeners: Int
    let lastPlaying: String?
    let playlists: [Playlist]

    var bestQualityPlaylist: Playlist? {
        playlists.first { $0.quality == .highest && $0.format == .aac }
            ?? playlists.first { $0.quality == .highest }
            ?? playlists.first { $0.quality == .high }
            ?? playlists.first
    }

    init(
        id: String,
        title: String,
        description: String? = nil,
        listeners: Int = 0,
        lastPlaying: String? = nil,
        playlists: [Playlist]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.listeners = listeners
        self.lastPlaying = lastPlaying
        self.playlists = playlists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        lastPlaying = try container.decodeIfPresent(String.self, forKey: .lastPlaying)

        if let value = try? container.decode(Int.self, forKey: .listeners) {
            listeners = value
        } else if let value = try? container.decode(String.self, forKey: .listeners) {
            listeners = Int(value) ?? 0
        } else {
            listeners = 0
        }

        playlists = try container.decodeIfPresent([LossyDecodable<Playlist>].self, forKey: .playlists)?
            .compactMap(\.value) ?? []
    }
}

struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}
