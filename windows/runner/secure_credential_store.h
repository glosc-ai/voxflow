#ifndef RUNNER_SECURE_CREDENTIAL_STORE_H_
#define RUNNER_SECURE_CREDENTIAL_STORE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Owns VoxFlow's secure-credential platform channel and keeps all DPAPI and
// registry implementation details out of the window module.
class SecureCredentialStore {
 public:
  explicit SecureCredentialStore(flutter::BinaryMessenger* messenger);
  ~SecureCredentialStore();

  SecureCredentialStore(const SecureCredentialStore&) = delete;
  SecureCredentialStore& operator=(const SecureCredentialStore&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SECURE_CREDENTIAL_STORE_H_
