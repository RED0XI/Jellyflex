#ifndef RUNNER_APP_SHELL_H_
#define RUNNER_APP_SHELL_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

// Anbindung an die Windows-Shell:
// - Sprungliste der Taskleiste ("Weiterschauen" per Rechtsklick)
// - Weitergabe von Aufrufen (z. B. aus der Sprungliste) an das schon offene
//   Fenster, damit keine zweite App startet.
//
// Dart-Seite: lib/core/app_shell.dart (Kanal "jellyflex/shell").
class AppShell {
 public:
  // Kennung der WM_COPYDATA-Nachricht ("JF").
  static constexpr ULONG_PTR kCopyDataId = 0x4A46;
  // Fensterklasse des Hauptfensters (zum Wiederfinden durch eine zweite Instanz).
  static constexpr const wchar_t* kWindowClass = L"JELLYFLEX_WINDOW";

  explicit AppShell(flutter::BinaryMessenger* messenger);
  ~AppShell();

  // Aufruf einer zweiten Instanz (Befehlszeile) an Dart weiterreichen.
  void Forward(const std::wstring& command_line);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_APP_SHELL_H_
