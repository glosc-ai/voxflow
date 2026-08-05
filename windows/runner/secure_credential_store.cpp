#include "secure_credential_store.h"

#include <windows.h>
#include <wincrypt.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <utility>
#include <variant>
#include <vector>

#include <flutter/standard_method_codec.h>

namespace {

constexpr char kChannelName[] =
    "ai.glosc.voxflow/secure_credentials/v1";
constexpr wchar_t kRegistryPath[] = L"Software\\Glosc AI\\VoxFlow";
constexpr wchar_t kRegistryValue[] = L"ApiKeyV1";
constexpr wchar_t kCredentialDescription[] =
    L"VoxFlow API credential version 1";
constexpr std::size_t kMaximumApiKeyBytes = 64 * 1024;
constexpr DWORD kMaximumProtectedBytes =
    static_cast<DWORD>(kMaximumApiKeyBytes + 16 * 1024);

enum class StoreError {
  kNone,
  kInvalidArgument,
  kUnavailable,
  kCorrupt,
};

struct ReadResult {
  StoreError error = StoreError::kNone;
  std::optional<std::string> value;
};

class ScopedRegistryKey {
 public:
  ScopedRegistryKey() = default;
  ~ScopedRegistryKey() {
    if (key_) {
      ::RegCloseKey(key_);
    }
  }

  ScopedRegistryKey(const ScopedRegistryKey&) = delete;
  ScopedRegistryKey& operator=(const ScopedRegistryKey&) = delete;

  HKEY* Receive() { return &key_; }
  HKEY get() const { return key_; }

 private:
  HKEY key_ = nullptr;
};

void ClearString(std::string* value) {
  if (value && !value->empty()) {
    ::SecureZeroMemory(value->data(), value->size());
    value->clear();
  }
}

void ClearVector(std::vector<BYTE>* value) {
  if (value && !value->empty()) {
    ::SecureZeroMemory(value->data(), value->size());
    value->clear();
  }
}

void ClearAndFreeBlob(DATA_BLOB* blob) {
  if (!blob || !blob->pbData) {
    return;
  }
  if (blob->cbData > 0) {
    ::SecureZeroMemory(blob->pbData, blob->cbData);
  }
  ::LocalFree(blob->pbData);
  blob->pbData = nullptr;
  blob->cbData = 0;
}

bool IsValidUtf8(const std::string& value) {
  if (value.empty() || value.size() > kMaximumApiKeyBytes ||
      std::find(value.begin(), value.end(), '\0') != value.end()) {
    return false;
  }
  return ::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                               static_cast<int>(value.size()), nullptr, 0) > 0;
}

ReadResult ReadCredential() {
  DWORD protected_size = 0;
  DWORD value_type = 0;
  LSTATUS status = ::RegGetValueW(
      HKEY_CURRENT_USER, kRegistryPath, kRegistryValue, RRF_RT_REG_BINARY,
      &value_type, nullptr, &protected_size);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) {
    return {};
  }
  if (status == ERROR_UNSUPPORTED_TYPE) {
    return {StoreError::kCorrupt, std::nullopt};
  }
  if (status != ERROR_SUCCESS) {
    return {StoreError::kUnavailable, std::nullopt};
  }
  if (value_type != REG_BINARY || protected_size == 0 ||
      protected_size > kMaximumProtectedBytes) {
    return {StoreError::kCorrupt, std::nullopt};
  }

  std::vector<BYTE> protected_value(protected_size);
  DWORD actual_size = protected_size;
  value_type = 0;
  status = ::RegGetValueW(
      HKEY_CURRENT_USER, kRegistryPath, kRegistryValue, RRF_RT_REG_BINARY,
      &value_type, protected_value.data(), &actual_size);
  if (status == ERROR_UNSUPPORTED_TYPE) {
    ClearVector(&protected_value);
    return {StoreError::kCorrupt, std::nullopt};
  }
  if (status != ERROR_SUCCESS) {
    ClearVector(&protected_value);
    return {StoreError::kUnavailable, std::nullopt};
  }
  if (value_type != REG_BINARY || actual_size == 0 ||
      actual_size > protected_value.size()) {
    ClearVector(&protected_value);
    return {StoreError::kCorrupt, std::nullopt};
  }
  protected_value.resize(actual_size);

  DATA_BLOB protected_blob{
      static_cast<DWORD>(protected_value.size()), protected_value.data()};
  DATA_BLOB plaintext_blob{};
  LPWSTR description = nullptr;
  const BOOL decrypted = ::CryptUnprotectData(
      &protected_blob, &description, nullptr, nullptr, nullptr,
      CRYPTPROTECT_UI_FORBIDDEN, &plaintext_blob);
  const DWORD decrypt_error = decrypted ? ERROR_SUCCESS : ::GetLastError();
  ClearVector(&protected_value);
  if (description) {
    ::LocalFree(description);
  }
  if (!decrypted) {
    ClearAndFreeBlob(&plaintext_blob);
    return {decrypt_error == ERROR_INVALID_DATA ? StoreError::kCorrupt
                                                : StoreError::kUnavailable,
            std::nullopt};
  }
  if (!plaintext_blob.pbData || plaintext_blob.cbData == 0 ||
      plaintext_blob.cbData > kMaximumApiKeyBytes) {
    ClearAndFreeBlob(&plaintext_blob);
    return {StoreError::kCorrupt, std::nullopt};
  }

  std::string value(reinterpret_cast<const char*>(plaintext_blob.pbData),
                    plaintext_blob.cbData);
  ClearAndFreeBlob(&plaintext_blob);
  if (!IsValidUtf8(value)) {
    ClearString(&value);
    return {StoreError::kCorrupt, std::nullopt};
  }
  ReadResult result;
  result.value.emplace(std::move(value));
  ClearString(&value);
  return result;
}

StoreError WriteCredential(const std::string& value) {
  if (!IsValidUtf8(value)) {
    return StoreError::kInvalidArgument;
  }

  DATA_BLOB plaintext_blob{
      static_cast<DWORD>(value.size()),
      reinterpret_cast<BYTE*>(const_cast<char*>(value.data()))};
  DATA_BLOB protected_blob{};
  if (!::CryptProtectData(&plaintext_blob, kCredentialDescription, nullptr,
                          nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN,
                          &protected_blob)) {
    ClearAndFreeBlob(&protected_blob);
    return StoreError::kUnavailable;
  }
  if (!protected_blob.pbData || protected_blob.cbData == 0 ||
      protected_blob.cbData > kMaximumProtectedBytes) {
    ClearAndFreeBlob(&protected_blob);
    return StoreError::kUnavailable;
  }

  ScopedRegistryKey registry_key;
  DWORD disposition = 0;
  LSTATUS status = ::RegCreateKeyExW(
      HKEY_CURRENT_USER, kRegistryPath, 0, nullptr, REG_OPTION_NON_VOLATILE,
      KEY_SET_VALUE, nullptr, registry_key.Receive(), &disposition);
  if (status == ERROR_SUCCESS) {
    status = ::RegSetValueExW(registry_key.get(), kRegistryValue, 0, REG_BINARY,
                              protected_blob.pbData,
                              protected_blob.cbData);
  }
  ClearAndFreeBlob(&protected_blob);
  return status == ERROR_SUCCESS ? StoreError::kNone
                                 : StoreError::kUnavailable;
}

StoreError DeleteCredential() {
  ScopedRegistryKey registry_key;
  const LSTATUS open_status =
      ::RegOpenKeyExW(HKEY_CURRENT_USER, kRegistryPath, 0, KEY_SET_VALUE,
                      registry_key.Receive());
  if (open_status == ERROR_FILE_NOT_FOUND ||
      open_status == ERROR_PATH_NOT_FOUND) {
    return StoreError::kNone;
  }
  if (open_status != ERROR_SUCCESS) {
    return StoreError::kUnavailable;
  }

  const LSTATUS delete_status =
      ::RegDeleteValueW(registry_key.get(), kRegistryValue);
  if (delete_status == ERROR_SUCCESS ||
      delete_status == ERROR_FILE_NOT_FOUND) {
    return StoreError::kNone;
  }
  return StoreError::kUnavailable;
}

void SendError(
    StoreError error,
    flutter::MethodResult<flutter::EncodableValue>* result) {
  switch (error) {
    case StoreError::kInvalidArgument:
      result->Error("invalid_argument",
                    "The API key must be a non-empty valid UTF-8 string.");
      return;
    case StoreError::kCorrupt:
      result->Error("secure_storage_corrupt",
                    "Secure credential storage is corrupted.");
      return;
    case StoreError::kUnavailable:
    case StoreError::kNone:
      result->Error("secure_storage_unavailable",
                    "Secure credential storage is unavailable.");
      return;
  }
}

}  // namespace

SecureCredentialStore::SecureCredentialStore(
    flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });
}

SecureCredentialStore::~SecureCredentialStore() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void SecureCredentialStore::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "readApiKey") {
    ReadResult read_result = ReadCredential();
    if (read_result.error != StoreError::kNone) {
      SendError(read_result.error, result.get());
      return;
    }
    if (!read_result.value.has_value()) {
      result->Success();
      return;
    }

    flutter::EncodableValue response(std::move(read_result.value.value()));
    ClearString(&read_result.value.value());
    result->Success(response);
    if (auto* value = std::get_if<std::string>(&response)) {
      ClearString(value);
    }
    return;
  }

  if (call.method_name() == "writeApiKey") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      SendError(StoreError::kInvalidArgument, result.get());
      return;
    }
    const auto value_iterator =
        arguments->find(flutter::EncodableValue("value"));
    if (value_iterator == arguments->end()) {
      SendError(StoreError::kInvalidArgument, result.get());
      return;
    }
    const auto* value = std::get_if<std::string>(&value_iterator->second);
    if (!value) {
      SendError(StoreError::kInvalidArgument, result.get());
      return;
    }

    const StoreError write_error = WriteCredential(*value);
    if (write_error != StoreError::kNone) {
      SendError(write_error, result.get());
      return;
    }
    result->Success();
    return;
  }

  if (call.method_name() == "deleteApiKey") {
    const StoreError delete_error = DeleteCredential();
    if (delete_error != StoreError::kNone) {
      SendError(delete_error, result.get());
      return;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}
