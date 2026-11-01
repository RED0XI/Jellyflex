import MediaPlayer

#if os(macOS)
  import Cocoa
  import FlutterMacOS
  private typealias PlatformImage = NSImage
#else
  import AVFoundation
  import Flutter
  import UIKit
  private typealias PlatformImage = UIImage
#endif

/// "Now Playing" im Kontrollzentrum, in der Menüleiste bzw. auf dem Sperrbildschirm und
/// Medientasten (Gegenstück: lib/core/media_session.dart und windows/runner/media_session.cpp).
/// Dieselbe Datei gehört zu macOS und iOS (ios/Runner verweist hierher).
///
/// Kanal `jellyflex/media_session`: `prepare`, `update`, `setPlaying`, `progress`, `clear`;
/// Tastendrücke kommen als `button` ("play", "pause", "stop", "next", "previous",
/// "skipForward", "skipBackward", "seek:<Sekunden>") zurück.
final class MediaSession {
  static let shared = MediaSession()

  private var channel: FlutterMethodChannel?
  private var info: [String: Any] = [:]
  /// Eigener Zustand: `playbackState` des Info-Centers gibt es nur unter macOS.
  private var playing = false
  private var artUrl = ""
  private var artTask: URLSessionDataTask?
  private let artLoader = ArtworkLoader()

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
      guard let self else { return .commandFailed }
      self.send(self.playing ? "pause" : "play")
      return .success
    }
    // 10 s vor/zurück (Sperrbildschirm, Kopfhörer) und Ziehen an der Leiste.
    commands.skipForwardCommand.preferredIntervals = [10]
    commands.skipBackwardCommand.preferredIntervals = [10]
    bind(commands.skipForwardCommand, "skipForward")
    bind(commands.skipBackwardCommand, "skipBackward")
    commands.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
      self?.send("seek:\(event.positionTime)")
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
    commands.skipForwardCommand.isEnabled = enabled
    commands.skipBackwardCommand.isEnabled = enabled
    commands.changePlaybackPositionCommand.isEnabled = enabled
  }

  /// Wiedergabe-Zustand setzen: macOS kennt `playbackState`, iOS liest ihn aus der Rate.
  private func setPlaying(_ value: Bool) {
    playing = value
    let center = MPNowPlayingInfoCenter.default()
    #if os(macOS)
      center.playbackState = value ? .playing : .paused
    #else
      if value { activateAudio() }
    #endif
    if info[MPMediaItemPropertyTitle] != nil {
      info[MPNowPlayingInfoPropertyPlaybackRate] = value ? (info[MPNowPlayingInfoPropertyDefaultPlaybackRate] ?? 1.0) : 0.0
      center.nowPlayingInfo = info
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = MPNowPlayingInfoCenter.default()
    switch call.method {
    case "prepare":
      // Vor dem Öffnen eines Videos: Ohne aktive Audio-Sitzung findet der Player kein
      // Ausgabegerät, iOS hält die App beim Sperren nicht wach und zeigt sie nicht als "Jetzt läuft".
      #if os(iOS)
        activateAudio()
      #endif
      result(nil)
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
      setPlaying(args["playing"] as? Bool ?? true)
      loadArtwork(args["artUrl"] as? String ?? "")
      result(nil)
    case "setPlaying":
      setPlaying(call.arguments as? Bool ?? false)
      result(nil)
    case "progress":
      // Position, Länge und Tempo – die Anzeige zählt von hier aus selbst weiter.
      guard let args = call.arguments as? [String: Any], info[MPMediaItemPropertyTitle] != nil else {
        result(nil)
        return
      }
      let rate = args["rate"] as? Double ?? 1.0
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = args["position"] as? Double ?? 0
      info[MPMediaItemPropertyPlaybackDuration] = args["duration"] as? Double ?? 0
      info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = rate
      info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? rate : 0.0
      center.nowPlayingInfo = info
      result(nil)
    case "clear":
      artTask?.cancel()
      artUrl = ""
      info = [:]
      playing = false
      center.nowPlayingInfo = nil
      #if os(macOS)
        center.playbackState = .stopped
      #endif
      setEnabled(false, canNext: false)
      // Sitzung freigeben – Musik anderer Apps darf weiterlaufen.
      #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      #endif
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  #if os(iOS)
    private func activateAudio() {
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .moviePlayback)
      try? session.setActive(true)
    }
  #endif

  /// Bild nur über https/http laden (feste Bildadresse des Servers, ohne Anmelde-Token).
  private func loadArtwork(_ url: String) {
    guard url != artUrl else { return }
    artUrl = url
    artTask?.cancel()
    info.removeValue(forKey: MPMediaItemPropertyArtwork)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    guard let target = URL(string: url), target.scheme == "https" || target.scheme == "http" else { return }
    artTask = artLoader.load(target) { [weak self] image in
      DispatchQueue.main.async {
        guard let self = self, self.artUrl == url else { return }
        self.info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.info
      }
    }
  }
}

/// Lädt Cover-Bilder höchstens bis [limit] Bytes: zu große Antworten werden schon
/// während der Übertragung abgebrochen statt erst vollständig in den Speicher geladen.
private final class ArtworkLoader: NSObject, URLSessionDataDelegate {
  static let limit = 20 * 1024 * 1024

  /// Alle Rückrufe der Session laufen nacheinander auf dieser Queue – `pending` braucht keine Sperre.
  private let queue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
  private var pending: [Int: (data: Data, done: (PlatformImage) -> Void)] = [:]

  func load(_ url: URL, done: @escaping (PlatformImage) -> Void) -> URLSessionDataTask {
    let task = session.dataTask(with: url)
    // Erst eintragen, dann starten – beides auf der Queue, damit kein Rückruf zu früh kommt.
    queue.addOperation {
      self.pending[task.taskIdentifier] = (Data(), done)
      task.resume()
    }
    return task
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    // Angekündigte Größe schon zu groß: gar nicht erst laden.
    completionHandler(response.expectedContentLength > Int64(ArtworkLoader.limit) ? .cancel : .allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let id = dataTask.taskIdentifier
    guard var entry = pending[id] else { return }
    entry.data.append(data)
    if entry.data.count > ArtworkLoader.limit {
      pending[id] = nil
      dataTask.cancel()
      return
    }
    pending[id] = entry
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let entry = pending.removeValue(forKey: task.taskIdentifier), error == nil,
      let image = PlatformImage(data: entry.data)
    else { return }
    entry.done(image)
  }
}
