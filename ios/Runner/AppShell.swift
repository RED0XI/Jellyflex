import Flutter
import Network
import UIKit

/// Anbindung an iOS (Gegenstücke: lib/core/app_shell.dart, macos/Runner/AppShell.swift).
///
/// Kanal `jellyflex/shell`:
/// - `connectionCost`: "metered" bei Mobilfunk, Handy-Hotspot oder "Datensparmodus",
///   sonst "unrestricted" bzw. "none" – Downloads warten so auf WLAN.
///
/// Alles Weitere (Dock-Menü, Stammzertifikate, Klänge …) gibt es hier noch nicht; Dart
/// fängt die fehlenden Methoden ab.
final class AppShell: NSObject {
  static let shared = AppShell()

  private var channel: FlutterMethodChannel?
  private let monitor = NWPathMonitor()
  private var path: NWPath?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/shell", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "connectionCost":
        result(self?.connectionCost() ?? "unknown")
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
