import Cocoa
import FlutterMacOS
import IOKit.ps

/// Stromversorgung (Gegenstück: lib/core/power.dart).
///
/// Kanal `jellyflex/power`:
/// - `status`: `{"battery": Bool, "lowPower": Bool}` – läuft der Mac gerade auf Akku,
///   ist der Stromsparmodus an?
/// - Änderungen (Netzteil ab/an, Stromsparmodus) meldet `changed` mit demselben Inhalt an Dart.
final class Power: NSObject {
  static let shared = Power()

  private var channel: FlutterMethodChannel?
  private var source: CFRunLoopSource?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/power", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "status", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.status())
    }
    // Netzteil an/ab.
    let context = Unmanaged.passUnretained(self).toOpaque()
    if let source = IOPSNotificationCreateRunLoopSource({ context in
      guard let context else { return }
      Unmanaged<Power>.fromOpaque(context).takeUnretainedValue().notify()
    }, context)?.takeRetainedValue() {
      CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
      self.source = source
    }
    // Stromsparmodus (Systemeinstellungen → Batterie).
    NotificationCenter.default.addObserver(
      self, selector: #selector(powerStateChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
  }

  @objc private func powerStateChanged() {
    DispatchQueue.main.async { self.notify() }
  }

  private func notify() {
    channel?.invokeMethod("changed", arguments: status())
  }

  private func status() -> [String: Bool] {
    var battery = false
    if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue()
    {
      battery = (type as String) == kIOPSBatteryPowerValue
    }
    return ["battery": battery, "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled]
  }
}
