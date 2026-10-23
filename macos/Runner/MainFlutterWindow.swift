import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Startgröße wie unter Windows (windows/runner/main.cpp); main.dart setzt danach die
    // endgültige Größe. Nie größer als der sichtbare Bildschirm.
    var size = NSSize(width: 1280, height: 720)
    if let visible = NSScreen.main?.visibleFrame.size {
      size = NSSize(width: min(size.width, visible.width), height: min(size.height, visible.height))
    }
    self.setContentSize(size)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Eigene Kanäle (Gegenstücke zu windows/runner/app_shell.cpp und media_session.cpp).
    let messenger = flutterViewController.engine.binaryMessenger
    AppShell.shared.register(with: messenger)
    MediaSession.shared.register(with: messenger)
    Keychain.register(with: messenger)

    super.awakeFromNib()
  }
}
