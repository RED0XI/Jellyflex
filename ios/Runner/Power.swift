import Flutter
import UIKit

/// Stromversorgung (Gegenstücke: lib/core/power.dart, macos/Runner/Power.swift).
///
/// Kanal `jellyflex/power`:
/// - `status`: `{"battery": Bool, "lowPower": Bool}` – läuft das Gerät gerade ohne Ladekabel,
///   ist der Stromsparmodus an?
/// - Änderungen (Ladekabel, Stromsparmodus) meldet `changed` mit demselben Inhalt an Dart.
final class Power: NSObject {
  static let shared = Power()

  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/power", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "status", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.status())
    }
    UIDevice.current.isBatteryMonitoringEnabled = true
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(changed), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    center.addObserver(
      self, selector: #selector(changed), name: .NSProcessInfoPowerStateDidChange, object: nil)
  }

  @objc private func changed() {
    DispatchQueue.main.async { self.channel?.invokeMethod("changed", arguments: self.status()) }
  }

  private func status() -> [String: Bool] {
    // Im Simulator ist der Zustand "unbekannt" – gilt wie am Ladekabel.
    let battery = UIDevice.current.batteryState == .unplugged
    return ["battery": battery, "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled]
  }
}
