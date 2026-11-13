import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Videos mit Ton auch bei stummgeschaltetem iPhone (wie jede Video-App).
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Eigene Kanäle (Gegenstücke zu macos/Runner/MainFlutterWindow.swift).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "Jellyflex") else { return }
    let messenger = registrar.messenger()
    AppShell.shared.register(with: messenger)
    ApplePlayer.shared.register(with: messenger)
    Keychain.register(with: messenger)
    MediaSession.shared.register(with: messenger)
    Power.shared.register(with: messenger)
  }
}
