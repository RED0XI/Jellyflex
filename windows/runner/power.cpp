#include "power.h"

#include <flutter/standard_method_codec.h>

#include <cstring>
#include <optional>

namespace {

// GUID_POWER_SAVING_STATUS (winnt.h): Energiesparmodus an/aus. Hier selbst definiert, damit kein
// <initguid.h> nötig ist.
constexpr GUID kPowerSavingStatus = {0xE00958C0, 0xC213, 0x4ACE, {0xAC, 0x77, 0xFE, 0xCC, 0xED, 0x2E, 0xEE, 0xA5}};

// [saver]: Energiesparmodus, wie ihn Windows gerade gemeldet hat – sonst nachfragen.
flutter::EncodableValue Status(std::optional<bool> saver = std::nullopt) {
  bool battery = false;
  bool low_power = false;
  SYSTEM_POWER_STATUS status{};
  if (::GetSystemPowerStatus(&status)) {
    // ACLineStatus: 0 = Akku, 1 = Netz, 255 = unbekannt (gilt als Netz – etwa PCs ohne Akku).
    battery = status.ACLineStatus == 0;
    // SystemStatusFlag: 1 = Energiesparmodus an.
    low_power = status.SystemStatusFlag == 1;
  }
  if (saver) low_power = *saver;
  return flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("battery"), flutter::EncodableValue(battery)},
      {flutter::EncodableValue("lowPower"), flutter::EncodableValue(low_power)},
  });
}

}  // namespace

Power::Power(flutter::BinaryMessenger* messenger, HWND hwnd) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "jellyflex/power", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "status") {
      result->Success(Status());
    } else {
      result->NotImplemented();
    }
  });
  // Netzteil an/ab meldet Windows jedem Fenster von selbst (PBT_APMPOWERSTATUSCHANGE); den
  // Energiesparmodus nur auf Wunsch (PBT_POWERSETTINGCHANGE).
  saver_notification_ = ::RegisterPowerSettingNotification(hwnd, &kPowerSavingStatus, DEVICE_NOTIFY_WINDOW_HANDLE);
}

Power::~Power() {
  if (saver_notification_) ::UnregisterPowerSettingNotification(saver_notification_);
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

void Power::HandlePowerBroadcast(WPARAM event, LPARAM data) {
  std::optional<bool> saver;
  if (event == PBT_POWERSETTINGCHANGE) {
    const auto* setting = reinterpret_cast<const POWERBROADCAST_SETTING*>(data);
    if (!setting || !::IsEqualGUID(setting->PowerSetting, kPowerSavingStatus) || setting->DataLength < sizeof(DWORD)) {
      return;
    }
    DWORD value = 0;
    memcpy(&value, setting->Data, sizeof(DWORD));
    saver = value != 0;
  } else if (event != PBT_APMPOWERSTATUSCHANGE) {
    return;
  }
  channel_->InvokeMethod("changed", std::make_unique<flutter::EncodableValue>(Status(saver)));
}
