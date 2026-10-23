import FlutterMacOS
import Foundation
import Security

/// Schlüssel für den verschlüsselten Speicher (Gegenstück: lib/core/secure_store.dart).
///
/// Kanal `jellyflex/keychain`, Methode `storeKey`: liefert einen zufälligen
/// 256-Bit-Schlüssel aus dem Schlüsselbund des Benutzers und legt ihn beim ersten
/// Mal an. Er verlässt das Gerät nie (nicht über iCloud synchronisiert) und ist erst
/// nach der ersten Anmeldung nach einem Neustart lesbar.
enum Keychain {
  private static let service = "Jellyflex"
  private static let account = "secure-store-key"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "jellyflex/keychain", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "storeKey" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if let key = loadOrCreateKey() {
        result(FlutterStandardTypedData(bytes: key))
      } else {
        result(FlutterError(code: "keychain", message: "Schlüsselbund nicht verfügbar", details: nil))
      }
    }
  }

  private static func loadOrCreateKey() -> Data? {
    if let existing = load() { return existing }
    var bytes = Data(count: 32)
    let status = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }
    guard status == errSecSuccess else { return nil }
    let add: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: "Jellyflex",
      kSecAttrSynchronizable as String: false,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: bytes,
    ]
    switch SecItemAdd(add as CFDictionary, nil) {
    case errSecSuccess: return bytes
    // Gleichzeitig von anderer Stelle angelegt – den vorhandenen nehmen.
    case errSecDuplicateItem: return load()
    default: return nil
    }
  }

  private static func load() -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data, data.count == 32
    else { return nil }
    return data
  }
}
