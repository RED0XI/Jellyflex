#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "media_session.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  media_session_ = std::make_unique<MediaSession>(
      flutter_controller_->engine()->messenger(), GetHandle());
  app_shell_ = std::make_unique<AppShell>(flutter_controller_->engine()->messenger());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  media_session_ = nullptr;
  app_shell_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // Aufruf einer zweiten Instanz (z. B. Klick in der Sprungliste).
  if (message == WM_COPYDATA && app_shell_) {
    auto* data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
    if (data && data->dwData == AppShell::kCopyDataId && data->lpData && data->cbData <= 4096 &&
        data->cbData % sizeof(wchar_t) == 0) {
      const auto* text = static_cast<const wchar_t*>(data->lpData);
      size_t length = data->cbData / sizeof(wchar_t);
      while (length > 0 && text[length - 1] == L'\0') length--;
      app_shell_->Forward(std::wstring(text, length));
      return TRUE;
    }
  }

  if (message == MediaSession::kButtonMessage && media_session_) {
    media_session_->DispatchButton(wparam);
    return 0;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
