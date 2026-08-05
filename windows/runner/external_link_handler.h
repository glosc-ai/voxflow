#ifndef RUNNER_EXTERNAL_LINK_HANDLER_H_
#define RUNNER_EXTERNAL_LINK_HANDLER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Owns the platform channel that opens HTTPS links in the user's default
// browser. URL validation is repeated natively so the channel cannot be used
// to launch files, executables, or custom URI schemes.
class ExternalLinkHandler {
 public:
  explicit ExternalLinkHandler(flutter::BinaryMessenger* messenger);
  ~ExternalLinkHandler();

  ExternalLinkHandler(const ExternalLinkHandler&) = delete;
  ExternalLinkHandler& operator=(const ExternalLinkHandler&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_EXTERNAL_LINK_HANDLER_H_
