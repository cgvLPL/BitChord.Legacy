import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

final class PlaybackManager: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var queue: [Track] = []
    @Published var notice: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var interruptionObserver: NSObjectProtocol?

    init() {
        configureAudioSession()
        configureRemoteCommands()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .began { self?.isPlaying = false }
        }
    }

    deinit {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        if let observer = interruptionObserver { NotificationCenter.default.removeObserver(observer) }
    }

    func play(_ track: Track, replacingQueue: Bool = true) {
        guard let url = track.streamURL else {
            currentTrack = track
            isPlaying = false
            notice = "No direct audio URL is available for this result. Configure a compatible source or open it in YouTube Music."
            updateNowPlaying()
            return
        }
        if replacingQueue { queue = [track] }
        currentTrack = track
        notice = nil
        player?.pause()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        observePlaybackTime()
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
        notice = "Added to queue"
    }

    func playNext() {
        guard queue.count > 1 else { return }
        let next = queue.removeFirst()
        queue.insert(currentTrack ?? next, at: 0)
        play(next, replacingQueue: false)
    }

    func playPrevious() {
        guard currentTime > 3 else { playNext(); return }
        seek(to: 0)
    }

    func togglePlayback() {
        guard let player = player else { return }
        if isPlaying { player.pause(); isPlaying = false }
        else { player.play(); isPlaying = true }
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        let safe = max(0, seconds.isFinite ? seconds : 0)
        player?.seek(to: CMTime(seconds: safe, preferredTimescale: 600))
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            notice = "Audio session could not be activated: \(error.localizedDescription)"
        }
    }

    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            guard let self = self, self.player != nil else { return .commandFailed }
            self.player?.play(); self.isPlaying = true; self.updateNowPlaying()
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause(); self?.isPlaying = false; self?.updateNowPlaying()
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayback()
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    private func observePlaybackTime() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
            let seconds = self.player?.currentItem?.duration.seconds ?? 0
            self.duration = seconds.isFinite ? seconds : 0
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
