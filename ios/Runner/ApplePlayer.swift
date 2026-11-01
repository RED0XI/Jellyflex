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
/// - `stop`
/// Meldungen an Dart: `progress` {position, paused} (alle 10 s und bei Pause/Weiter),
/// `restore` {position} (zurück in den Jellyflex-Player), `ended` {position, finished}.
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
        self.cleanUp()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: Öffnen

  private func open(_ args: [String: Any], result: @escaping FlutterResult) {
    cleanUp()
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

    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)

    // Erst bei bekannter Länge an die alte Stelle springen.
    observations.append(
      item.observe(\.status, options: [.new]) { [weak self] item, _ in
        guard let self, item.status == .readyToPlay, self.startPosition > 0 else { return }
        let target = CMTime(seconds: self.startPosition, preferredTimescale: 600)
        self.startPosition = 0
        item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: nil)
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
    let host = UIView(frame: CGRect(x: 0, y: window.bounds.height - 2, width: 2, height: 2))
    host.isUserInteractionEnabled = false
    host.alpha = 0.01
    let layer = AVPlayerLayer(player: player)
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
    // Sobald iOS bereit ist, das Fenster öffnen.
    observations.append(
      pip.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { pip, _ in
        guard pip.isPictureInPicturePossible, !pip.isPictureInPictureActive else { return }
        DispatchQueue.main.async { pip.startPictureInPicture() }
      })
    player.play()
    // Kommt nichts zustande (Stream lädt nicht …), nicht ewig warten.
    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
      guard let self, let pending = self.pipResult else { return }
      self.pipResult = nil
      self.cleanUp()
      pending(false)
    }
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
  }
}

// MARK: - Bild-in-Bild (direkt)

extension ApplePlayer: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    inPip = true
    pipResult?(true)
    pipResult = nil
  }

  func pictureInPictureController(
    _ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error
  ) {
    pipResult?(false)
    pipResult = nil
    cleanUp()
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
