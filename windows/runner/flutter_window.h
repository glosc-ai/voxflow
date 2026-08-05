#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

class SecureCredentialStore;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Lets resize hit tests fall through from the edge-to-edge Flutter child
  // window to its native parent while preserving normal Flutter input in the
  // client area.
  static LRESULT CALLBACK FlutterViewSubclassProc(
      HWND window, UINT message, WPARAM wparam, LPARAM lparam,
      UINT_PTR subclass_id, DWORD_PTR reference_data) noexcept;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  std::unique_ptr<SecureCredentialStore> secure_credential_store_;

  HWND flutter_view_handle_ = nullptr;
  bool flutter_view_subclass_installed_ = false;

  bool startup_resize_pending_ = false;
  int startup_window_width_ = 0;
  int startup_window_height_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
