#include "external_link_handler.h"

#include <windows.h>
#include <shellapi.h>

#include <cstddef>
#include <limits>
#include <string>
#include <utility>
#include <variant>

#include <flutter/standard_method_codec.h>

namespace {

constexpr char kChannelName[] = "ai.glosc.voxflow/external_links/v1";
constexpr char kOpenMethod[] = "open";
constexpr std::size_t kMaximumUrlBytes = 8 * 1024;
constexpr char kAllowedUrl[] = "https://www.glosc.ai/keys";

enum class OpenResult {
  kSuccess,
  kInvalidUrl,
  kUnavailable,
};

std::wstring Utf16FromUtf8(const std::string& value) {
  if (value.empty() || value.size() > kMaximumUrlBytes ||
      value.size() > static_cast<std::size_t>((std::numeric_limits<int>::max)()) ||
      value.find('\0') != std::string::npos) {
    return {};
  }

  const int input_length = static_cast<int>(value.size());
  const int output_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(), input_length, nullptr, 0);
  if (output_length <= 0) {
    return {};
  }

  std::wstring converted(static_cast<std::size_t>(output_length), L'\0');
  if (::MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                            input_length, converted.data(), output_length) !=
      output_length) {
    return {};
  }
  return converted;
}

OpenResult OpenHttpsUrl(const std::string& value) {
  if (value != kAllowedUrl) {
    return OpenResult::kInvalidUrl;
  }
  const std::wstring url = Utf16FromUtf8(value);
  if (url.empty()) {
    return OpenResult::kInvalidUrl;
  }

  const HINSTANCE result =
      ::ShellExecuteW(nullptr, L"open", url.c_str(), nullptr, nullptr,
                      SW_SHOWNORMAL);
  return reinterpret_cast<INT_PTR>(result) > 32 ? OpenResult::kSuccess
                                                : OpenResult::kUnavailable;
}

void SendError(OpenResult error,
               flutter::MethodResult<flutter::EncodableValue>* result) {
  if (error == OpenResult::kInvalidUrl) {
    result->Error("invalid_url", "Only valid HTTPS links can be opened.");
    return;
  }
  result->Error("cannot_open_url",
                "The system browser could not open this link.");
}

}  // namespace

ExternalLinkHandler::ExternalLinkHandler(flutter::BinaryMessenger* messenger)
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

ExternalLinkHandler::~ExternalLinkHandler() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void ExternalLinkHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != kOpenMethod) {
    result->NotImplemented();
    return;
  }

  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!arguments) {
    SendError(OpenResult::kInvalidUrl, result.get());
    return;
  }
  const auto url_iterator = arguments->find(flutter::EncodableValue("url"));
  if (url_iterator == arguments->end()) {
    SendError(OpenResult::kInvalidUrl, result.get());
    return;
  }
  const auto* url = std::get_if<std::string>(&url_iterator->second);
  if (!url) {
    SendError(OpenResult::kInvalidUrl, result.get());
    return;
  }

  const OpenResult open_result = OpenHttpsUrl(*url);
  if (open_result != OpenResult::kSuccess) {
    SendError(open_result, result.get());
    return;
  }
  result->Success();
}
