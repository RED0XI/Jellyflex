import Cocoa
import FlutterMacOS
import MediaPlayer

/// "Now Playing" im Kontrollzentrum/der Menüleiste und Medientasten
/// (Gegenstück: lib/core/media_session.dart und windows/runner/media_session.cpp).
///
/// Kanal `jellyflex/media_session`: `update`, `setPlaying`, `clear`;
/// Tastendrücke kommen als `button` ("play", "pause", "stop", "next", "previous") zurück.
final class MediaSession {
  static let shared = MediaSession()

  private var channel: FlutterMethodChannel?
  private var info: [String: Any] = [:]
  private var artUrl = ""
  private var artTask: URLSessionDataTask?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/media_session", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    let commands = MPRemoteCommandCenter.shared()
    bind(commands.playCommand, "play")
    bind(commands.pauseCommand, "pause")
    bind(commands.stopCommand, "stop")
    bind(commands.nextTrackCommand, "next")
    bind(commands.previousTrackCommand, "previous")
    commands.togglePlayPauseCommand.addTarget { [weak self] _ in
      let playing = MPNowPlayingInfoCenter.default().playbackState == .playing
      self?.send(playing ? "pause" : "play")
      return .success
    }
    setEnabled(false, canNext: false)
  }

  private func bind(_ command: MPRemoteCommand, _ name: String) {
    command.addTarget { [weak self] _ in
      self?.send(name)
      return .success
    }
  }

  private func send(_ button: String) {
    DispatchQueue.main.async { self.channel?.invokeMethod("button", arguments: button) }
  }

  private func setEnabled(_ enabled: Bool, canNext: Bool) {
    let commands = MPRemoteCommandCenter.shared()
    commands.playCommand.isEnabled = enabled
    commands.pauseCommand.isEnabled = enabled
    commands.stopCommand.isEnabled = enabled
    commands.togglePlayPauseCommand.isEnabled = enabled
    commands.nextTrackCommand.isEnabled = enabled && canNext
    commands.previousTrackCommand.isEnabled = false
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = MPNowPlayingInfoCenter.default()
    switch call.method {
    case "update":
      guard let args = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      setEnabled(true, canNext: args["canNext"] as? Bool ?? false)
      let title = args["title"] as? String ?? ""
      let subtitle = args["subtitle"] as? String ?? ""
      info[MPMediaItemPropertyTitle] = title
      info[MPMediaItemPropertyArtist] = subtitle
      info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
      center.nowPlayingInfo = info
      center.playbackState = (args["playing"] as? Bool ?? true) ? .playing : .paused
      loadArtwork(args["artUrl"] as? String ?? "")
      result(nil)
    case "setPlaying":
      center.playbackState = (call.arguments as? Bool ?? false) ? .playing : .paused
      result(nil)
    case "clear":
      artTask?.cancel()
      artUrl = ""
      info = [:]
      center.nowPlayingInfo = nil
      center.playbackState = .stopped
      setEnabled(false, canNext: false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Bild nur über https/http laden (feste Bildadresse des Servers, ohne Anmelde-Token).
  private func loadArtwork(_ url: String) {
    guard url != artUrl else { return }
    artUrl = url
    artTask?.cancel()
    info.removeValue(forKey: MPMediaItemPropertyArtwork)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    guard let target = URL(string: url), target.scheme == "https" || target.scheme == "http" else { return }
    artTask = URLSession.shared.dataTask(with: target) { [weak self] data, _, _ in
      guard let data = data, data.count < 20 * 1024 * 1024, let image = NSImage(data: data) else { return }
      DispatchQueue.main.async {
        guard let self = self, self.artUrl == url else { return }
        self.info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.info
      }
    }
    artTask?.resume()
  }
}
