import Cocoa
import FlutterMacOS
import Network
import Security

/// Anbindung an macOS (Gegenstück: lib/core/app_shell.dart und windows/runner/app_shell.cpp).
///
/// Kanal `jellyflex/shell`:
/// - `setJumpList`: "Weiterschauen" im Dock-Menü (Rechtsklick aufs Dock-Symbol) –
///   das Gegenstück zur Sprungliste der Windows-Taskleiste. Ein Klick meldet
///   `open` mit `--resume=<Kennung>` an Dart, genau wie unter Windows.
/// - `connectionCost`: "metered" bei teurer/eingeschränkter Verbindung (Handy-Hotspot,
///   Modus für geringe Datennutzung), sonst "unrestricted" bzw. "none".
/// - `trustedRoots`: vertrauenswürdige Stammzertifikate (DER) für den Video-Player.
/// - `loadSound`/`playSound`: kurze Oberflächen-Klänge aus dem Speicher.
/// - `requestAttention`: Dock-Symbol hüpft einmal (Download im Hintergrund fertig).
final class AppShell: NSObject {
  static let shared = AppShell()

  private var channel: FlutterMethodChannel?
  private var dockItems: [(title: String, arguments: String)] = []
  private var dockCategory = ""
  private var sounds: [String: NSSound] = [:]
  private var playing: NSSound?

  private let monitor = NWPathMonitor()
  private var path: NWPath?

  func register(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "jellyflex/shell", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async { self?.path = path }
    }
    monitor.start(queue: DispatchQueue(label: "jellyflex.network"))
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setJumpList":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "args", message: "Map erwartet", details: nil))
        return
      }
      dockCategory = args["category"] as? String ?? ""
      dockItems = (args["items"] as? [[String: Any]] ?? []).compactMap { item in
        guard let title = item["title"] as? String, let arguments = item["arguments"] as? String else { return nil }
        return (title, arguments)
      }
      result(true)
    case "connectionCost":
      result(connectionCost())
    case "trustedRoots":
      DispatchQueue.global(qos: .userInitiated).async {
        let roots = AppShell.trustedRoots().map { FlutterStandardTypedData(bytes: $0) }
        DispatchQueue.main.async { result(roots) }
      }
    case "loadSound":
      guard let args = call.arguments as? [String: Any],
        let name = args["name"] as? String,
        let data = args["data"] as? FlutterStandardTypedData,
        let sound = NSSound(data: data.data)
      else {
        result(false)
        return
      }
      sounds[name] = sound
      result(true)
    case "playSound":
      guard let name = call.arguments as? String, let sound = sounds[name] else {
        result(false)
        return
      }
      // Ein neuer Klang beendet den vorherigen (wie PlaySound unter Windows).
      playing?.stop()
      sound.stop()
      sound.play()
      playing = sound
      result(true)
    case "requestAttention":
      NSApp.requestUserAttention(.informationalRequest)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Dock-Menü

  /// Wird von AppDelegate.applicationDockMenu abgefragt.
  func dockMenu() -> NSMenu? {
    guard !dockItems.isEmpty else { return nil }
    let menu = NSMenu()
    if !dockCategory.isEmpty {
      let header = NSMenuItem(title: dockCategory, action: nil, keyEquivalent: "")
      header.isEnabled = false
      menu.addItem(header)
    }
    for item in dockItems {
      let entry = NSMenuItem(title: item.title, action: #selector(openDockItem(_:)), keyEquivalent: "")
      entry.target = self
      entry.representedObject = item.arguments
      menu.addItem(entry)
    }
    return menu
  }

  @objc private func openDockItem(_ sender: NSMenuItem) {
    guard let arguments = sender.representedObject as? String else { return }
    NSApp.activate(ignoringOtherApps: true)
    channel?.invokeMethod("open", arguments: arguments)
  }

  // MARK: Verbindung

  private func connectionCost() -> String {
    guard let path = path else { return "unknown" }
    if path.status != .satisfied { return "none" }
    // isExpensive: Mobilfunk bzw. Handy-Hotspot; isConstrained: "Geringe Datennutzung".
    if path.isExpensive || path.isConstrained { return "metered" }
    return "unrestricted"
  }

  // MARK: Stammzertifikate

  /// Stammzertifikate, denen macOS für TLS vertraut: die des Systems sowie selbst
  /// hinzugefügte (Administrator/Benutzer), sofern sie dort als vertrauenswürdig markiert sind.
  static func trustedRoots() -> [Data] {
    var result: [Data] = []
    var seen = Set<Data>()
    for domain in [SecTrustSettingsDomain.system, .admin, .user] {
      var list: CFArray?
      guard SecTrustSettingsCopyCertificates(domain, &list) == errSecSuccess,
        let certificates = list as? [SecCertificate]
      else { continue }
      for certificate in certificates {
        guard domain == .system || isTrustedRoot(certificate, domain: domain) else { continue }
        let der = SecCertificateCopyData(certificate) as Data
        if seen.insert(der).inserted { result.append(der) }
      }
    }
    return result
  }

  /// Gilt das Zertifikat laut Vertrauenseinstellungen als Stammzertifikat (für SSL oder allgemein)?
  private static func isTrustedRoot(_ certificate: SecCertificate, domain: SecTrustSettingsDomain) -> Bool {
    var settings: CFArray?
    guard SecTrustSettingsCopyTrustSettings(certificate, domain, &settings) == errSecSuccess else { return false }
    let entries = settings as? [[String: Any]] ?? []
    // Leere Liste = "immer vertrauen" (als Stammzertifikat).
    if entries.isEmpty { return true }
    for entry in entries {
      if let policy = entry[kSecTrustSettingsPolicy as String] {
        // Nur Einträge ohne Richtlinie oder für SSL zählen.
        let policyInfo = SecPolicyCopyProperties(policy as! SecPolicy) as? [String: Any]
        let oid = policyInfo?[kSecPolicyOid as String] as? String
        if oid != (kSecPolicyAppleSSL as String) { continue }
      }
      let raw = (entry[kSecTrustSettingsResult as String] as? NSNumber)?.uint32Value
        ?? SecTrustSettingsResult.trustRoot.rawValue
      if raw == SecTrustSettingsResult.trustRoot.rawValue || raw == SecTrustSettingsResult.trustAsRoot.rawValue {
        return true
      }
      if raw == SecTrustSettingsResult.deny.rawValue { return false }
    }
    return false
  }
}
