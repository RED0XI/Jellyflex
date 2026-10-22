#include "media_session.h"

#include <flutter/standard_method_codec.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>

#include <string>

namespace wm = winrt::Windows::Media;
namespace wf = winrt::Windows::Foundation;
namespace wss = winrt::Windows::Storage::Streams;

namespace {

enum Button : WPARAM { kPlay = 1, kPause, kStop, kNext, kPrevious };

std::string GetString(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return {};
  if (auto value = std::get_if<std::string>(&it->second)) return *value;
  return {};
}

bool GetBool(const flutter::EncodableMap& map, const char* key, bool fallback) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return fallback;
  if (auto value = std::get_if<bool>(&it->second)) return *value;
  return fallback;
}

}  // namespace

struct MediaSession::Impl {
  HWND hwnd = nullptr;
  wm::SystemMediaTransportControls smtc{nullptr};
  winrt::event_token button_token{};
};

MediaSession::MediaSession(flutter::BinaryMessenger* messenger, HWND hwnd)
    : impl_(std::make_unique<Impl>()) {
  impl_->hwnd = hwnd;
  try {
    auto interop = winrt::get_activation_factory<wm::SystemMediaTransportControls,
                                                 ISystemMediaTransportControlsInterop>();
    winrt::check_hresult(interop->GetForWindow(
        hwnd, winrt::guid_of<wm::SystemMediaTransportControls>(),
        winrt::put_abi(impl_->smtc)));

    HWND target = hwnd;
    impl_->button_token = impl_->smtc.ButtonPressed(
        [target](const wm::SystemMediaTransportControls&,
                 const wm::SystemMediaTransportControlsButtonPressedEventArgs& args) {
          WPARAM button = 0;
          switch (args.Button()) {
            case wm::SystemMediaTransportControlsButton::Play: button = kPlay; break;
            case wm::SystemMediaTransportControlsButton::Pause: button = kPause; break;
            case wm::SystemMediaTransportControlsButton::Stop: button = kStop; break;
            case wm::SystemMediaTransportControlsButton::Next: button = kNext; break;
            case wm::SystemMediaTransportControlsButton::Previous: button = kPrevious; break;
            default: return;
          }
          // Dieser Rückruf kommt aus einem WinRT-Thread → in den UI-Thread schicken.
          PostMessage(target, MediaSession::kButtonMessage, button, 0);
        });
  } catch (...) {
    impl_->smtc = nullptr;  // Ohne Medienanzeige weiterlaufen.
  }

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "jellyflex/media_session", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });
}

MediaSession::~MediaSession() {
  if (impl_ && impl_->smtc) {
    try {
      impl_->smtc.ButtonPressed(impl_->button_token);
      impl_->smtc.DisplayUpdater().ClearAll();
      impl_->smtc.IsEnabled(false);
    } catch (...) {
    }
  }
}

void MediaSession::DispatchButton(WPARAM button) {
  const char* name = nullptr;
  switch (button) {
    case kPlay: name = "play"; break;
    case kPause: name = "pause"; break;
    case kStop: name = "stop"; break;
    case kNext: name = "next"; break;
    case kPrevious: name = "previous"; break;
    default: return;
  }
  channel_->InvokeMethod("button", std::make_unique<flutter::EncodableValue>(std::string(name)));
}

void MediaSession::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto& smtc = impl_->smtc;
  if (!smtc) {
    result->Success();  // Nicht verfügbar – stillschweigend ignorieren.
    return;
  }

  try {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());

    if (call.method_name() == "update" && args) {
      smtc.IsEnabled(true);
      smtc.IsPlayEnabled(true);
      smtc.IsPauseEnabled(true);
      smtc.IsStopEnabled(true);
      smtc.IsNextEnabled(GetBool(*args, "canNext", false));
      smtc.IsPreviousEnabled(false);
      smtc.PlaybackStatus(GetBool(*args, "playing", true) ? wm::MediaPlaybackStatus::Playing
                                                          : wm::MediaPlaybackStatus::Paused);

      auto updater = smtc.DisplayUpdater();
      updater.Type(wm::MediaPlaybackType::Video);
      updater.VideoProperties().Title(winrt::to_hstring(GetString(*args, "title")));
      updater.VideoProperties().Subtitle(winrt::to_hstring(GetString(*args, "subtitle")));
      const auto art = GetString(*args, "artUrl");
      if (!art.empty()) {
        updater.Thumbnail(wss::RandomAccessStreamReference::CreateFromUri(wf::Uri(winrt::to_hstring(art))));
      } else {
        updater.Thumbnail(nullptr);
      }
      updater.Update();
      result->Success();
    } else if (call.method_name() == "setPlaying" && call.arguments()) {
      const auto* playing = std::get_if<bool>(call.arguments());
      smtc.PlaybackStatus(playing && *playing ? wm::MediaPlaybackStatus::Playing
                                              : wm::MediaPlaybackStatus::Paused);
      result->Success();
    } else if (call.method_name() == "clear") {
      smtc.DisplayUpdater().ClearAll();
      smtc.PlaybackStatus(wm::MediaPlaybackStatus::Closed);
      smtc.IsEnabled(false);
      result->Success();
    } else {
      result->NotImplemented();
    }
  } catch (const winrt::hresult_error& e) {
    result->Error("smtc", winrt::to_string(e.message()));
  } catch (...) {
    result->Error("smtc", "Unbekannter Fehler");
  }
}
