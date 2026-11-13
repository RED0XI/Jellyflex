#ifndef RUNNER_POWER_H_
#define RUNNER_POWER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Stromversorgung (Gegenstück zu macos/Runner/Power.swift).
//
// Kanal "jellyflex/power":
// - "status": {"battery": bool, "lowPower": bool} – läuft der Rechner gerade auf Akku,
//   ist der Energiesparmodus von Windows an?
// - Änderungen (Netzteil ab/an, Energiesparmodus) meldet "changed" mit demselben Inhalt an Dart.
//
// Dart-Seite: lib/core/power.dart.
class Power {
 public:
  Power(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~Power();

  // Im UI-Thread aufrufen (aus FlutterWindow::MessageHandler) – bei WM_POWERBROADCAST
  // (wparam, lparam der Nachricht).
  void HandlePowerBroadcast(WPARAM event, LPARAM data);

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HPOWERNOTIFY saver_notification_ = nullptr;
};

#endif  // RUNNER_POWER_H_
