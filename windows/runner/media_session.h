#ifndef RUNNER_MEDIA_SESSION_H_
#define RUNNER_MEDIA_SESSION_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Anbindung an die Windows-Medienanzeige (System Media Transport Controls):
// Titel/Bild im Lautstärke-Overlay und Medientasten der Tastatur – auch wenn
// das Fenster nicht im Vordergrund ist.
//
// Dart-Seite: lib/core/media_session.dart (Kanal "jellyflex/media_session").
class MediaSession {
 public:
  // Fensternachricht, mit der Tastendrücke vom WinRT-Thread zurück in den
  // UI-Thread geschickt werden.
  static constexpr UINT kButtonMessage = WM_APP + 0x4A;

  MediaSession(flutter::BinaryMessenger* messenger, HWND hwnd);
  ~MediaSession();

  // Im UI-Thread aufrufen (aus FlutterWindow::MessageHandler).
  void DispatchButton(WPARAM button);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  struct Impl;
  std::unique_ptr<Impl> impl_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_MEDIA_SESSION_H_
