import AVFoundation
import Flutter
import Network
import UIKit

/// Anbindung an iOS (Gegenstücke: lib/core/app_shell.dart, macos/Runner/AppShell.swift).
///
/// Kanal `jellyflex/shell`:
/// - `connectionCost`: "metered" bei Mobilfunk, Handy-Hotspot oder "Datensparmodus",
///   sonst "unrestricted" bzw. "none" – Downloads warten so auf WLAN.
/// - `loadSound`/`playSound`: kurze Oberflächen-Klänge aus dem Speicher.
/// - `getBrightness`/`setBrightness`: Bildschirmhelligkeit 0…1 (Wischen im Player).
///
/// Alles Weitere (Dock-Menü, Stammzertifikate …) gibt es hier noch nicht; Dart fängt die
/// fehlenden Methoden ab.
final class AppShell: NSObject {
  static let shared = AppShell()

  private var channel: FlutterMethodChannel?
  private let monitor = NWPathMonitor()
  private var path: NWPath?
  private var sounds: [String: AVAudioPlayer] = [:]

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/shell", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "connectionCost":
        result(self?.connectionCost() ?? "unknown")
      case "loadSound":
        guard let args = call.arguments as? [String: Any],
          let name = args["name"] as? String,
          let data = args["data"] as? FlutterStandardTypedData,
          let player = try? AVAudioPlayer(data: data.data)
        else {
          result(false)
          return
        }
        player.prepareToPlay()
        self?.sounds[name] = player
        result(true)
      case "playSound":
        guard let name = call.arguments as? String, let player = self?.sounds[name] else {
          result(false)
          return
        }
        // Ein neuer Klang beginnt von vorn (wie unter macOS und Windows).
        player.currentTime = 0
        player.play()
        result(true)
      case "getBrightness":
        // Bildschirmhelligkeit 0…1 (Wischen links im Player).
        result(Double(UIScreen.main.brightness))
      case "setBrightness":
        guard let value = call.arguments as? Double else {
          result(false)
          return
        }
        UIScreen.main.brightness = CGFloat(min(max(value, 0), 1))
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async { self?.path = path }
    }
    monitor.start(queue: DispatchQueue(label: "jellyflex.network"))
  }

  private func connectionCost() -> String {
    guard let path = path else { return "unknown" }
    if path.status != .satisfied { return "none" }
    // isExpensive: Mobilfunk bzw. Hotspot; isConstrained: "Datensparmodus".
    if path.isExpensive || path.isConstrained { return "metered" }
    return "unrestricted"
  }
}
