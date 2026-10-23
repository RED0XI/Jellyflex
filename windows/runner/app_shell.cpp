#include "app_shell.h"

#include <flutter/standard_method_codec.h>
#include <objectarray.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shobjidl.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Networking.Connectivity.h>
#include <wrl/client.h>

#include <algorithm>
#include <string>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace {

std::wstring Utf8ToWide(const std::string& text) {
  if (text.empty()) return {};
  int size = ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), result.data(), size);
  return result;
}

std::string WideToUtf8(const std::wstring& text) {
  if (text.empty()) return {};
  int size = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0, nullptr,
                                   nullptr);
  std::string result(size, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), result.data(), size, nullptr,
                        nullptr);
  return result;
}

std::string GetString(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return {};
  if (auto value = std::get_if<std::string>(&it->second)) return *value;
  return {};
}

std::wstring ExePath() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  return std::wstring(path, length);
}

// Verknüpfung auf die eigene .exe mit Argumenten und Titel.
ComPtr<IShellLinkW> MakeLink(const std::wstring& exe, const std::wstring& title, const std::wstring& args) {
  ComPtr<IShellLinkW> link;
  if (FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link)))) return nullptr;
  link->SetPath(exe.c_str());
  link->SetArguments(args.c_str());
  link->SetIconLocation(exe.c_str(), 0);
  link->SetDescription(title.c_str());
  ComPtr<IPropertyStore> store;
  if (FAILED(link.As(&store))) return nullptr;
  PROPVARIANT value;
  if (FAILED(::InitPropVariantFromString(title.c_str(), &value))) return nullptr;
  HRESULT hr = store->SetValue(PKEY_Title, value);
  ::PropVariantClear(&value);
  if (FAILED(hr) || FAILED(store->Commit())) return nullptr;
  return link;
}

// Sprungliste neu setzen; ohne Einträge wird sie geleert.
bool SetJumpList(const std::wstring& category, const std::vector<std::pair<std::wstring, std::wstring>>& items) {
  ComPtr<ICustomDestinationList> list;
  if (FAILED(::CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list)))) {
    return false;
  }
  if (items.empty()) return SUCCEEDED(list->DeleteList(nullptr));

  UINT max_slots = 0;
  ComPtr<IObjectArray> removed;
  if (FAILED(list->BeginList(&max_slots, IID_PPV_ARGS(&removed)))) return false;
  ComPtr<IObjectCollection> collection;
  if (FAILED(::CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&collection)))) {
    list->AbortList();
    return false;
  }
  // Vom Benutzer aus der Sprungliste entfernte Einträge dürfen nicht wieder
  // hinein – sonst schlägt AppendCategory fehl.
  std::vector<std::wstring> removed_args;
  UINT removed_count = 0;
  if (removed && SUCCEEDED(removed->GetCount(&removed_count))) {
    for (UINT i = 0; i < removed_count; i++) {
      ComPtr<IShellLinkW> link;
      if (SUCCEEDED(removed->GetAt(i, IID_PPV_ARGS(&link)))) {
        wchar_t args[1024] = {};
        if (SUCCEEDED(link->GetArguments(args, 1024))) removed_args.emplace_back(args);
      }
    }
  }
  const std::wstring exe = ExePath();
  UINT added = 0;
  for (const auto& [title, args] : items) {
    if (added >= max_slots) break;
    if (std::find(removed_args.begin(), removed_args.end(), args) != removed_args.end()) continue;
    if (auto link = MakeLink(exe, title, args)) {
      collection->AddObject(link.Get());
      added++;
    }
  }
  ComPtr<IObjectArray> array;
  if (FAILED(collection.As(&array)) || FAILED(list->AppendCategory(category.c_str(), array.Get()))) {
    list->AbortList();
    return false;
  }
  return SUCCEEDED(list->CommitList());
}

// Art der Internetverbindung laut Windows: "none" (keine), "metered" (getaktet –
// mobile Daten, Handy-Hotspot, als getaktet markiertes WLAN) oder "unrestricted".
std::string ConnectionCost() {
  try {
    namespace nc = winrt::Windows::Networking::Connectivity;
    auto profile = nc::NetworkInformation::GetInternetConnectionProfile();
    if (!profile) return "none";
    auto cost = profile.GetConnectionCost();
    if (cost.Roaming() || cost.NetworkCostType() == nc::NetworkCostType::Fixed ||
        cost.NetworkCostType() == nc::NetworkCostType::Variable) {
      return "metered";
    }
    return "unrestricted";
  } catch (...) {
    return "unknown";
  }
}

}  // namespace

AppShell::AppShell(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "jellyflex/shell", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });
}

AppShell::~AppShell() {
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

void AppShell::Forward(const std::wstring& command_line) {
  channel_->InvokeMethod("open", std::make_unique<flutter::EncodableValue>(WideToUtf8(command_line)));
}

void AppShell::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "connectionCost") {
    result->Success(flutter::EncodableValue(ConnectionCost()));
    return;
  }
  if (call.method_name() != "setJumpList") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) {
    result->Error("args", "Map erwartet");
    return;
  }
  std::vector<std::pair<std::wstring, std::wstring>> items;
  auto it = args->find(flutter::EncodableValue("items"));
  if (it != args->end()) {
    if (const auto* list = std::get_if<flutter::EncodableList>(&it->second)) {
      for (const auto& entry : *list) {
        if (const auto* map = std::get_if<flutter::EncodableMap>(&entry)) {
          items.emplace_back(Utf8ToWide(GetString(*map, "title")), Utf8ToWide(GetString(*map, "arguments")));
        }
      }
    }
  }
  result->Success(flutter::EncodableValue(SetJumpList(Utf8ToWide(GetString(*args, "category")), items)));
}
