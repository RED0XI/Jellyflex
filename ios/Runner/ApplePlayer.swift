import AVFoundation
import AVKit
import Flutter
import UIKit

/// Apples eigener Player für Bild-in-Bild und AirPlay (Gegenstück: lib/features/player/apple_player.dart).
///
/// mpv – der Player von Jellyflex – zeichnet in eine Flutter-Textur. Daraus kann iOS weder ein
/// Bild-in-Bild-Fenster noch AirPlay-Video machen. Für beides übernimmt dieser Player den Titel
/// an derselben Stelle als HLS-Stream vom Server.
///
/// Kanal `jellyflex/apple_player`:
/// - `open` {url, headers, position, mode: "pip" | "airplay"} → läuft es? (Bool)
/// - `stop` → Stelle in Sekunden, an der dieser Player stand (oder nichts, wenn keiner lief)
/// Meldungen an Dart: `progress` {position, paused} (alle 10 s und bei Pause/Weiter),
/// `restore` {position} (zurück in den Jellyflex-Player), `ended` {position, finished}.
/// Frage an Dart: `position` → aktuelle Stelle des Jellyflex-Players (Sekunden) – der läuft
/// weiter, bis das Bild-in-Bild-Fenster steht, dann übernimmt dieser Player genau dort.
final class ApplePlayer: NSObject {
  static let shared = ApplePlayer()

  private var channel: FlutterMethodChannel?
  private var player: AVPlayer?
  private var startPosition: Double = 0

  // Bild-in-Bild direkt aus Jellyflex: eine winzige Ebene im Fenster (ohne sie startet kein PiP).
  private var host: UIView?
  private var pip: AVPictureInPictureController?
  private var pipResult: FlutterResult?

  // AirPlay: Apples Vollbild-Player mit AirPlay- und Bild-in-Bild-Knopf.
  private var viewController: AVPlayerViewController?

  private var observations: [NSKeyValueObservation] = []

  /// An die Startstelle gesprungen – erst dann öffnet sich das Bild-in-Bild-Fenster.
  private var seekedToStart = false
  private var readyForPip = false
  private var timeObserver: Any?
  private var endObserver: NSObjectProtocol?

  /// Läuft das Bild gerade im Bild-in-Bild-Fenster (egal aus welchem Weg)?
  private var inPip = false

  /// Zurück in den Jellyflex-Player angefordert – das Ende ist dann kein Ende.
  private var handedBack = false

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/apple_player", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "open":
        self.open(call.arguments as? [String: Any] ?? [:], result: result)
      case "stop":
        // Stelle zurückgeben, an der Apples Player stand (für den Fortschritt bei Jellyfin).
        let position: Double? = self.player == nil ? nil : self.position
        self.handedBack = true
        self.cleanUp()
        result(position)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: Öffnen

  /// Zählt die Aufrufe von `open` – ein Zeitlimit gilt nur für den Versuch, der es gestellt hat.
  private var openId = 0

  private func open(_ args: [String: Any], result: @escaping FlutterResult) {
    cleanUp()
    openId += 1
    guard let urlString = args["url"] as? String, let url = URL(string: urlString),
      url.scheme == "https" || url.scheme == "http"
    else {
      result(false)
      return
    }
    let headers = args["headers"] as? [String: String] ?? [:]
    // Anmeldung im Kopf jeder Anfrage (auch der HLS-Abschnitte) statt in der Adresse.
    let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    player.allowsExternalPlayback = true
    self.player = player
    startPosition = args["position"] as? Double ?? 0
    handedBack = false
    let mode = args["mode"] as? String ?? "pip"
    // Bild-in-Bild: stumm vorbereiten, solange der Jellyflex-Player noch spielt.
    if mode == "pip" { player.isMuted = true }

    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)

    // Erst bei bekannter Länge an die alte Stelle springen – beim Bild-in-Bild an die Stelle, an
    // der der Jellyflex-Player gerade ist (er lief weiter, während der Server den Stream vorbereitet hat).
    observations.append(
      item.observe(\.status, options: [.new]) { [weak self] item, _ in
        guard let self else { return }
        if item.status == .failed {
          NSLog("Jellyflex ApplePlayer: Stream nicht abspielbar: %@", item.error?.localizedDescription ?? "?")
          self.failPending()
          return
        }
        guard item.status == .readyToPlay, !self.seekedToStart else { return }
        self.seekedToStart = true
        let seek = { (seconds: Double) in
          self.startPosition = seconds
          let target = CMTime(seconds: seconds, preferredTimescale: 600)
          item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self, self.player === player else { return }
            self.startPosition = 0
            player.play()
            self.readyForPip = true
            self.startPipIfPossible()
          }
        }
        if mode == "pip" {
          self.channel?.invokeMethod("position", arguments: nil) { value in
            seek((value as? Double) ?? self.startPosition)
          }
        } else if self.startPosition > 0 {
          seek(self.startPosition)
        }
      })
    observations.append(
      player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
        guard player.timeControlStatus != .waitingToPlayAtSpecifiedRate else { return }
        self?.send("progress", ["position": self?.position ?? 0, "paused": player.timeControlStatus == .paused])
      })
    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: 10, preferredTimescale: 1), queue: .main
    ) { [weak self] _ in
      guard let self, let player = self.player else { return }
      self.send("progress", ["position": self.position, "paused": player.timeControlStatus == .paused])
    }
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
    ) { [weak self] _ in
      self?.finish(finished: true)
    }

    if args["mode"] as? String == "airplay" {
      presentFullScreen(player, result: result)
    } else {
      startPip(player, result: result)
    }
  }

  private var position: Double {
    guard let time = player?.currentTime(), time.isNumeric else { return startPosition }
    // Vor dem ersten Sprung steht der Player noch bei 0 – dann zählt die Startstelle.
    return startPosition > 0 ? startPosition : time.seconds
  }

  private var rootViewController: UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  // MARK: Bild-in-Bild direkt

  private func startPip(_ player: AVPlayer, result: @escaping FlutterResult) {
    guard AVPictureInPictureController.isPictureInPictureSupported(),
      let window = rootViewController?.view.window
    else {
      cleanUp()
      result(false)
      return
    }
    // Über das ganze Fenster (fast durchsichtig): Das Bild-in-Bild-Fenster schrumpft dann aus dem
    // Video heraus statt aus einer Ecke zu wachsen. Berührungen gehen weiter an Flutter.
    let host = UIView(frame: window.bounds)
    host.isUserInteractionEnabled = false
    host.alpha = 0.01
    let layer = AVPlayerLayer(player: player)
    layer.videoGravity = .resizeAspect
    layer.frame = host.bounds
    host.layer.addSublayer(layer)
    window.addSubview(host)
    self.host = host

    guard let pip = AVPictureInPictureController(playerLayer: layer) else {
      cleanUp()
      result(false)
      return
    }
    pip.delegate = self
    self.pip = pip
    pipResult = result
    // Sobald iOS bereit ist und der Stream an der richtigen Stelle steht, das Fenster öffnen.
    observations.append(
      pip.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, _ in
        DispatchQueue.main.async { self?.startPipIfPossible() }
      })
    // Kommt nichts zustande (Stream lädt nicht …), nicht ewig warten. Nur für diesen Versuch:
    // Ein früheres Zeitlimit bräche sonst einen späteren, noch wartenden Versuch vorzeitig ab.
    let attempt = openId
    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
      guard let self, self.openId == attempt, self.pipResult != nil else { return }
      NSLog("Jellyflex ApplePlayer: Bild-in-Bild kam nicht zustande (possible=%d, ready=%d)",
        self.pip?.isPictureInPicturePossible == true ? 1 : 0, self.readyForPip ? 1 : 0)
      self.failPending()
    }
  }

  private var pipStarting = false

  private func startPipIfPossible() {
    guard let pip, readyForPip, pipResult != nil, !pipStarting, pip.isPictureInPicturePossible,
      !pip.isPictureInPictureActive
    else { return }
    pipStarting = true
    pip.startPictureInPicture()
  }

  /// Öffnen ging schief: Dart Bescheid geben (der Jellyflex-Player spielt einfach weiter).
  private func failPending() {
    guard let pending = pipResult else {
      // Lief schon (AirPlay-Vollbild): zurück in den Jellyflex-Player statt ins Leere.
      handBack()
      return
    }
    pipResult = nil
    cleanUp()
    pending(false)
  }

  // MARK: Vollbild mit AirPlay

  private func presentFullScreen(_ player: AVPlayer, result: @escaping FlutterResult) {
    guard let root = rootViewController else {
      cleanUp()
      result(false)
      return
    }
    let controller = AVPlayerViewController()
    controller.player = player
    controller.delegate = self
    controller.allowsPictureInPicturePlayback = true
    controller.canStartPictureInPictureAutomaticallyFromInline = true
    controller.updatesNowPlayingInfoCenter = true
    controller.modalPresentationStyle = .fullScreen
    viewController = controller
    root.present(controller, animated: true) {
      player.play()
      result(true)
    }
  }

  // MARK: Ende

  private func send(_ method: String, _ args: [String: Any]) {
    DispatchQueue.main.async { self.channel?.invokeMethod(method, arguments: args) }
  }

  /// Zurück in den Jellyflex-Player an der aktuellen Stelle.
  private func handBack() {
    guard !handedBack, player != nil else { return }
    handedBack = true
    send("restore", ["position": position])
    cleanUp()
  }

  private func finish(finished: Bool) {
    guard !handedBack, player != nil else { return }
    handedBack = true
    send("ended", ["position": position, "finished": finished])
    cleanUp()
  }

  private func cleanUp() {
    // Wartet Dart noch auf die Antwort eines Bild-in-Bild-Versuchs, bekommt es sie jetzt
    // ("nicht zustande gekommen") – sonst wartete der Aufruf dort für immer.
    if let pending = pipResult {
      pipResult = nil
      pending(false)
    }
    observations.forEach { $0.invalidate() }
    observations = []
    if let timeObserver { player?.removeTimeObserver(timeObserver) }
    timeObserver = nil
    if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    endObserver = nil
    player?.pause()
    if let pip, pip.isPictureInPictureActive { pip.stopPictureInPicture() }
    pip = nil
    host?.removeFromSuperview()
    host = nil
    if let controller = viewController, controller.presentingViewController != nil {
      controller.dismiss(animated: true)
    }
    viewController = nil
    player = nil
    inPip = false
    seekedToStart = false
    readyForPip = false
    pipStarting = false
  }
}

// MARK: - Bild-in-Bild (direkt)

extension ApplePlayer: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
    // Ab jetzt ist das Fenster zu sehen: Ton hier an, der Jellyflex-Player hält an.
    player?.isMuted = false
    pipResult?(true)
    pipResult = nil
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    inPip = true
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("Jellyflex ApplePlayer: Bild-in-Bild nicht gestartet: %@", error.localizedDescription)
    failPending()
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    handBack()
    completionHandler(true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    // Fenster geschlossen (x) – ohne Rückkehr in die App.
    finish(finished: false)
  }
}

// MARK: - Vollbild (AirPlay)

extension ApplePlayer: AVPlayerViewControllerDelegate {
  func playerViewControllerWillStartPictureInPicture(_ controller: AVPlayerViewController) {
    inPip = true
  }

  func playerViewController(
    _ controller: AVPlayerViewController,
    willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
  ) {
    coordinator.animate(alongsideTransition: nil) { [weak self] context in
      // Geht es ins Bild-in-Bild-Fenster, läuft das Video weiter; sonst zurück zu Jellyflex.
      guard let self, !context.isCancelled, !self.inPip else { return }
      self.handBack()
    }
  }

  func playerViewController(
    _ controller: AVPlayerViewController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    handBack()
    completionHandler(true)
  }

  func playerViewControllerDidStopPictureInPicture(_ controller: AVPlayerViewController) {
    inPip = false
    finish(finished: false)
  }
}
