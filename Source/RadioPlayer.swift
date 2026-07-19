@preconcurrency import AVFoundation
import Foundation
@preconcurrency import MediaPlayer

enum PlaybackState: String {
    case idle
    case loading
    case playing
    case waiting
    case paused
    case failed
}

@MainActor
final class RadioPlayer: NSObject {
    private let player = AVPlayer()
    private var currentChannel: Channel?
    private var currentTrack: String?
    private var metadataOutput: AVPlayerItemMetadataOutput?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var failedToPlayToken: NSObjectProtocol?
    private var stalledToken: NSObjectProtocol?
    private var retryTask: Task<Void, Never>?
    private var retryCount = 0
    private var generation: UInt = 0
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var remoteCommandsActive = false

    private(set) var state: PlaybackState = .idle
    private(set) var wantsPlayback = false

    var stateChanged: ((PlaybackState) -> Void)?
    var trackChanged: ((String?) -> Void)?
    var playCommand: (() -> Bool)?
    var pauseCommand: (() -> Bool)?
    var toggleCommand: (() -> Bool)?
    var previousCommand: (() -> Bool)?
    var nextCommand: (() -> Bool)?

    init(volume: Float) {
        super.init()
        player.volume = volume
        player.automaticallyWaitsToMinimizeStalling = true
        observePlayer()
        configureRemoteCommands()
    }

    @discardableResult
    func play(_ channel: Channel) -> Bool {
        guard channel.bestQualityPlaylist != nil else {
            wantsPlayback = false
            transition(to: .failed)
            return false
        }

        wantsPlayback = true
        retryCount = 0
        retryTask?.cancel()
        activateRemoteCommands()

        currentTrack = nil
        if currentChannel?.id != channel.id {
            trackChanged?(nil)
        }
        currentChannel = channel
        installCurrentChannel()
        return true
    }

    @discardableResult
    func resume(_ channel: Channel) -> Bool {
        play(channel)
    }

    func pause() {
        wantsPlayback = false
        generation &+= 1
        retryTask?.cancel()
        retryTask = nil
        removeItemObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        transition(to: .paused)
    }

    func setVolume(_ volume: Float) {
        player.volume = min(max(volume, 0), 1)
    }

    func shutdown() {
        wantsPlayback = false
        retryTask?.cancel()
        removeItemObservers()
        timeControlObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)

        for (command, target) in remoteTargets {
            command.removeTarget(target)
            command.isEnabled = false
        }
        remoteTargets.removeAll()
        remoteCommandsActive = false

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
        transition(to: .idle)
    }

    nonisolated static func acceptsCallback(
        callbackGeneration: UInt,
        activeGeneration: UInt,
        wantsPlayback: Bool
    ) -> Bool {
        wantsPlayback && callbackGeneration == activeGeneration
    }

    private func observePlayer() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [
            .initial,
            .new
        ]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatus(status)
            }
        }
    }

    private func installCurrentChannel() {
        guard wantsPlayback,
              let channel = currentChannel,
              let playlist = channel.bestQualityPlaylist
        else {
            wantsPlayback = false
            transition(to: .failed)
            return
        }

        generation &+= 1
        let itemGeneration = generation
        removeItemObservers()

        let item = AVPlayerItem(url: playlist.url)
        let output = AVPlayerItemMetadataOutput(identifiers: nil)
        output.setDelegate(self, queue: .main)
        item.add(output)
        metadataOutput = output

        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                self?.handleItemStatus(status, generation: itemGeneration)
            }
        }

        failedToPlayToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleTerminalFailure(generation: itemGeneration)
            }
        }

        stalledToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      Self.acceptsCallback(
                          callbackGeneration: itemGeneration,
                          activeGeneration: self.generation,
                          wantsPlayback: self.wantsPlayback
                      ) else { return }
                self.transition(to: .waiting)
            }
        }

        player.replaceCurrentItem(with: item)
        transition(to: .loading)
        player.play()
    }

    private func removeItemObservers() {
        itemStatusObservation = nil
        metadataOutput?.setDelegate(nil, queue: nil)
        metadataOutput = nil

        if let failedToPlayToken {
            NotificationCenter.default.removeObserver(failedToPlayToken)
        }
        if let stalledToken {
            NotificationCenter.default.removeObserver(stalledToken)
        }
        failedToPlayToken = nil
        stalledToken = nil
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard wantsPlayback else { return }

        switch status {
        case .playing:
            retryCount = 0
            transition(to: .playing)
        case .waitingToPlayAtSpecifiedRate:
            transition(to: .waiting)
        case .paused:
            break
        @unknown default:
            transition(to: .waiting)
        }
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status, generation itemGeneration: UInt) {
        guard Self.acceptsCallback(
            callbackGeneration: itemGeneration,
            activeGeneration: generation,
            wantsPlayback: wantsPlayback
        ) else { return }

        if status == .failed {
            handleTerminalFailure(generation: itemGeneration)
        }
    }

    private func handleTerminalFailure(generation failedGeneration: UInt) {
        guard Self.acceptsCallback(
            callbackGeneration: failedGeneration,
            activeGeneration: generation,
            wantsPlayback: wantsPlayback
        ) else { return }

        if retryCount == 0 {
            retryCount = 1
            installCurrentChannel()
            return
        }

        if retryCount == 1 {
            retryCount = 2
            transition(to: .waiting)
            let retryGeneration = generation
            retryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled,
                      let self,
                      Self.acceptsCallback(
                          callbackGeneration: retryGeneration,
                          activeGeneration: self.generation,
                          wantsPlayback: self.wantsPlayback
                      ) else { return }
                installCurrentChannel()
            }
            return
        }

        wantsPlayback = false
        transition(to: .failed)
    }

    private func receiveTrack(_ track: String?, outputID: ObjectIdentifier? = nil) {
        if let outputID {
            guard metadataOutput.map(ObjectIdentifier.init) == outputID else { return }
        }
        let track = track?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let track, !track.isEmpty, track != currentTrack else { return }
        currentTrack = track
        trackChanged?(track)
        publishNowPlaying()
    }

    private func transition(to newState: PlaybackState) {
        guard state != newState else { return }
        state = newState
        stateChanged?(newState)
        publishNowPlaying()
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        addTarget(to: center.playCommand) { [weak self] in self?.playCommand?() ?? false }
        addTarget(to: center.pauseCommand) { [weak self] in self?.pauseCommand?() ?? false }
        addTarget(to: center.togglePlayPauseCommand) { [weak self] in self?.toggleCommand?() ?? false }
        addTarget(to: center.previousTrackCommand) { [weak self] in self?.previousCommand?() ?? false }
        addTarget(to: center.nextTrackCommand) { [weak self] in self?.nextCommand?() ?? false }

        let unsupportedCommands: [MPRemoteCommand] = [
            center.stopCommand,
            center.changePlaybackRateCommand,
            center.changeRepeatModeCommand,
            center.changeShuffleModeCommand,
            center.skipForwardCommand,
            center.skipBackwardCommand,
            center.seekForwardCommand,
            center.seekBackwardCommand,
            center.changePlaybackPositionCommand,
            center.ratingCommand,
            center.likeCommand,
            center.dislikeCommand,
            center.bookmarkCommand,
            center.enableLanguageOptionCommand,
            center.disableLanguageOptionCommand,
        ]
        unsupportedCommands.forEach { $0.isEnabled = false }
        setSupportedCommandsEnabled(false)
    }

    private func addTarget(to command: MPRemoteCommand, action: @escaping @MainActor @Sendable () -> Bool) {
        let target = command.addTarget { _ in
            Self.performOnMain(action)
        }
        remoteTargets.append((command, target))
    }

    private func activateRemoteCommands() {
        guard !remoteCommandsActive else { return }
        remoteCommandsActive = true
        setSupportedCommandsEnabled(true)
    }

    private func setSupportedCommandsEnabled(_ enabled: Bool) {
        let center = MPRemoteCommandCenter.shared()
        [
            center.playCommand,
            center.pauseCommand,
            center.togglePlayPauseCommand,
            center.previousTrackCommand,
            center.nextTrackCommand,
        ].forEach { $0.isEnabled = enabled }
    }

    private nonisolated static func performOnMain(
        _ action: @MainActor @Sendable () -> Bool
    ) -> MPRemoteCommandHandlerStatus {
        let succeeded: Bool = if Thread.isMainThread {
            MainActor.assumeIsolated { action() }
        } else {
            DispatchQueue.main.sync {
                MainActor.assumeIsolated { action() }
            }
        }
        return succeeded ? .success : .noActionableNowPlayingItem
    }

    private func publishNowPlaying() {
        guard remoteCommandsActive, let channel = currentChannel else { return }

        let rate = state == .playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: currentTrack ?? channel.title,
            MPMediaItemPropertyArtist: channel.title,
            MPMediaItemPropertyAlbumTitle: "SomaFM",
            MPNowPlayingInfoPropertyExternalContentIdentifier: channel.id,
            MPNowPlayingInfoPropertyServiceIdentifier: "SomaFM",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        MPNowPlayingInfoCenter.default().playbackState = switch state {
        case .playing: .playing
        case .paused: .paused
        case .loading, .waiting: .interrupted
        case .idle, .failed: .stopped
        }
    }
}

extension RadioPlayer: @preconcurrency AVPlayerItemMetadataOutputPushDelegate {
    func metadataOutput(
        _ output: AVPlayerItemMetadataOutput,
        didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
        from _: AVPlayerItemTrack?
    ) {
        let outputID = ObjectIdentifier(output)
        Task { [weak self] in
            let value = await Self.loadTrack(from: groups)
            self?.receiveTrack(value, outputID: outputID)
        }
    }

    private static func loadTrack(from groups: [AVTimedMetadataGroup]) async -> String? {
        for item in groups.flatMap(\.items) {
            if let value = try? await item.load(.stringValue) {
                return value
            }
        }
        return nil
    }
}
