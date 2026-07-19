import AppKit
import Foundation
import Testing
@testable import SomaFM_miniplayer

private final class BundleToken {}

struct SomaFMTests {
    @Test
    func capturedCatalogDecodes() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "channels", withExtension: "json"))
        let channels = try SomaAPI.decodeChannels(from: Data(contentsOf: url))

        #expect(channels.count == 46)
        #expect(channels.first { $0.id == "7soul" }?.description == "Vintage soul tracks from the original 45 RPM vinyl.")
        #expect(channels.allSatisfy { $0.bestQualityPlaylist != nil })
    }

    @Test
    func listenersDecodeFromStringsAndIntegers() throws {
        let channels = try SomaAPI.decodeChannels(from: Data(
            """
            {"channels":[
              {"id":"string","title":"String","listeners":"42","playlists":[{"url":"https://example.com/a.pls","format":"aac","quality":"highest"}]},
              {"id":"integer","title":"Integer","listeners":17,"playlists":[{"url":"https://example.com/b.pls","format":"mp3","quality":"high"}]}
            ]}
            """.utf8
        ))

        #expect(channels.map(\.listeners) == [42, 17])
    }

    @Test
    func unsupportedPlaylistsDoNotDiscardValidChannels() throws {
        let channels = try SomaAPI.decodeChannels(from: Data(
            """
            {"channels":[
              {"id":"valid","title":"Valid","listeners":"1","playlists":[
                {"url":"https://example.com/new.pls","format":"opus","quality":"highest"},
                {"url":"https://example.com/new-quality.pls","format":"aac","quality":"lossless"},
                {"url":"https://example.com/valid.pls","format":"aac","quality":"highest"}
              ]},
              {"title":"Malformed","playlists":[]}
            ]}
            """.utf8
        ))

        #expect(channels.count == 1)
        #expect(channels[0].playlists.map(\.url.absoluteString) == ["https://example.com/valid.pls"])
    }

    @Test
    func playlistPreferenceIsDeterministic() {
        let lowAAC = playlist("low-aac", format: .aac, quality: .low)
        let highMP3 = playlist("high-mp3", format: .mp3, quality: .high)
        let highestMP3 = playlist("highest-mp3", format: .mp3, quality: .highest)
        let highestAAC = playlist("highest-aac", format: .aac, quality: .highest)

        #expect(channel(playlists: [lowAAC, highMP3, highestMP3, highestAAC]).bestQualityPlaylist == highestAAC)
        #expect(channel(playlists: [lowAAC, highMP3, highestMP3]).bestQualityPlaylist == highestMP3)
        #expect(channel(playlists: [lowAAC, highMP3]).bestQualityPlaylist == highMP3)
        #expect(channel(playlists: [lowAAC]).bestQualityPlaylist == lowAAC)
    }

    @Test
    func sortingResolutionAndWraparound() {
        let alpha = channel(id: "alpha", title: "Alpha", listeners: 10)
        let groove = channel(id: "groovesalad", title: "Groove Salad", listeners: 30)
        let zulu = channel(id: "zulu", title: "Zulu", listeners: 20)
        let channels = [zulu, alpha, groove]

        #expect(sortChannels(channels, by: .default).map(\.id) == ["zulu", "alpha", "groovesalad"])
        #expect(sortChannels(channels, by: .listeners).map(\.id) == ["groovesalad", "zulu", "alpha"])
        #expect(sortChannels(channels, by: .alphabetically).map(\.id) == ["alpha", "groovesalad", "zulu"])
        #expect(adjacentChannel(in: channels, selectedID: "zulu", offset: -1)?.id == "groovesalad")
        #expect(adjacentChannel(in: channels, selectedID: "groovesalad", offset: 1)?.id == "zulu")
        #expect(resolveChannel(in: channels, savedID: "missing")?.id == "groovesalad")
    }

    @Test
    func recentIDsStaySmallUniqueAndValid() {
        #expect(addingRecent("a", to: ["b", "a", "c", "d", "e"]) == ["a", "b", "c", "d", "e"])
        #expect(addingRecent("f", to: ["a", "b", "c", "d", "e"]) == ["f", "a", "b", "c", "d"])
        #expect(existingChannelIDs(["a", "missing", "b"], in: [channel(id: "a"), channel(id: "b")]) == ["a", "b"])
    }

    @Test
    func trackActionsGeneratePercentEncodedSearchURLs() throws {
        #expect(TrackAction.copy.url(for: "Massive Attack & Hope") == nil)

        for action in TrackAction.allCases where action != .copy {
            let url = try #require(action.url(for: "Massive Attack & Hope"))
            #expect(url.absoluteString.contains("Massive%20Attack"))
            #expect(!url.absoluteString.contains(" "))
        }
    }

    @Test @MainActor
    func settingsCommandIsActionable() throws {
        let mainMenu = try #require(NSApp.mainMenu)
        let item = try #require(mainMenu.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .first {
                $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command)
            })
        let action = try #require(item.action)

        #expect(NSApp.sendAction(action, to: item.target, from: item))
    }

    @Test
    func playOnLaunchRunsOnceAfterChannelsArrive() {
        var gate = PlayOnLaunchGate(enabled: true)
        let beforeChannels = gate.consume(hasChannels: false)
        let afterChannels = gate.consume(hasChannels: true)
        let repeated = gate.consume(hasChannels: true)

        #expect(!beforeChannels)
        #expect(afterChannels)
        #expect(!repeated)
    }

    @Test
    func stalePlayerCallbacksAndPausedRetriesAreRejected() {
        #expect(RadioPlayer.acceptsCallback(callbackGeneration: 3, activeGeneration: 3, wantsPlayback: true))
        #expect(!RadioPlayer.acceptsCallback(callbackGeneration: 2, activeGeneration: 3, wantsPlayback: true))
        #expect(!RadioPlayer.acceptsCallback(callbackGeneration: 3, activeGeneration: 3, wantsPlayback: false))
    }

    @Test
    func legacyDefaultsRemainCompatible() {
        #expect(UserDefaultsKey.volume == "RadioPlayer.Volume")
        #expect(UserDefaultsKey.lastPlayedChannel == "RadioPlayer.Channel.LastPlayed")
        #expect(UserDefaultsKey.shouldPlayOnLaunch == "RadioPlayer.ShouldPlayOnLaunch")
        #expect(UserDefaultsKey.notificationsEnabled == "RadioPlayer.NotificationsEnabled")
        #expect(UserDefaultsKey.apiChannelsSortOrder == "SomaAPI.Channels.SortOrder")
        #expect(UserDefaultsKey.trackAction == "TrackSearch.Provider")
        #expect(ChannelsSortOrder.default.rawValue == 0)
        #expect(ChannelsSortOrder.listeners.rawValue == 1)
        #expect(ChannelsSortOrder.alphabetically.rawValue == 2)
    }

    private func playlist(
        _ name: String,
        format: Playlist.Format,
        quality: Playlist.Quality
    ) -> Playlist {
        Playlist(url: URL(string: "https://example.com/\(name).pls")!, format: format, quality: quality)
    }

    private func channel(
        id: String = "channel",
        title: String = "Channel",
        listeners: Int = 0,
        playlists: [Playlist]? = nil
    ) -> Channel {
        Channel(
            id: id,
            title: title,
            listeners: listeners,
            playlists: playlists ?? [playlist("default", format: .aac, quality: .highest)]
        )
    }
}
