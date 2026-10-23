import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// ⌘Q wie das Schließen des Fensters behandeln: So kann Dart (window_manager mit
  /// setPreventClose) vorher noch etwas erledigen – z. B. ein wartendes Update installieren.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    // Dart hat schon entschieden und beendet jetzt selbst (windowManager.destroy → terminate).
    if closeRequested { return .terminateNow }
    guard let window = mainFlutterWindow, window.isVisible, let delegate = window.delegate else {
      return .terminateNow
    }
    // Ohne Einspruch sofort beenden; sonst entscheidet Dart (und beendet danach selbst).
    if delegate.windowShouldClose?(window) ?? true { return .terminateNow }
    closeRequested = true
    return .terminateCancel
  }

  private var closeRequested = false

  /// "Weiterschauen" im Dock-Menü (Gegenstück zur Sprungliste der Windows-Taskleiste).
  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    return AppShell.shared.dockMenu()
  }
}
