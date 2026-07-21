#include "flutter_window.h"

#include <cstdint>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

namespace {

constexpr UINT kForceStartupRedrawMessage = WM_APP + 1;
constexpr UINT_PTR kStartupResizeTimerId = 0x5646;
constexpr UINT kStartupResizeDelayMs = 75;
constexpr int kStartupResizeDelta = 32;
constexpr char kWindowChannelName[] = "ai.glosc.voxflow/window";

}  // namespace

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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), kWindowChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "redraw") {
          ::PostMessage(GetHandle(), kForceStartupRedrawMessage, 0, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "nowUtcMicroseconds") {
          FILETIME file_time{};
          ::GetSystemTimePreciseAsFileTime(&file_time);
          ULARGE_INTEGER ticks{};
          ticks.LowPart = file_time.dwLowDateTime;
          ticks.HighPart = file_time.dwHighDateTime;
          constexpr std::uint64_t kWindowsToUnixEpochTicks =
              116444736000000000ULL;
          const auto microseconds = static_cast<std::int64_t>(
              (ticks.QuadPart - kWindowsToUnixEpochTicks) / 10);
          result->Success(flutter::EncodableValue(microseconds));
          return;
        }
        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    this->Show();
    // Queue the redraw after ShowWindow has returned. On some Windows GPU
    // configurations, repainting synchronously here leaves the first surface
    // white until the user resizes the window.
    ::PostMessage(GetHandle(), kForceStartupRedrawMessage, 0, 0);
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (GetHandle()) {
    ::KillTimer(GetHandle(), kStartupResizeTimerId);
  }
  startup_resize_pending_ = false;
  window_channel_.reset();
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

  switch (message) {
    case kForceStartupRedrawMessage: {
      if (flutter_controller_ && !startup_resize_pending_) {
        RECT window_bounds{};
        if (::GetWindowRect(hwnd, &window_bounds)) {
          const int window_width = window_bounds.right - window_bounds.left;
          const int window_height = window_bounds.bottom - window_bounds.top;
          if (window_width > 0 && window_height > 0) {
            constexpr UINT flags =
                SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE;
            // A native timer keeps the expanded and restored sizes in
            // separate compositor passes. Back-to-back messages can still be
            // coalesced by DWM, leaving the Flutter swap chain white until a
            // manual resize.
            if (::SetWindowPos(hwnd, nullptr, 0, 0,
                               window_width + kStartupResizeDelta,
                               window_height, flags)) {
              startup_resize_pending_ = true;
              startup_window_width_ = window_width;
              startup_window_height_ = window_height;
              if (::SetTimer(hwnd, kStartupResizeTimerId,
                             kStartupResizeDelayMs, nullptr)) {
                return 0;
              }
              startup_resize_pending_ = false;
              ::SetWindowPos(hwnd, nullptr, 0, 0, startup_window_width_,
                             startup_window_height_, flags);
            }
          }
        }
        const HWND view = flutter_controller_->view()->GetNativeWindow();
        ::RedrawWindow(view, nullptr, nullptr,
                       RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN);
        flutter_controller_->ForceRedraw();
      }
      return 0;
    }
    case WM_TIMER: {
      if (wparam != kStartupResizeTimerId) {
        break;
      }
      ::KillTimer(hwnd, kStartupResizeTimerId);
      startup_resize_pending_ = false;
      if (flutter_controller_) {
        constexpr UINT flags = SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE;
        ::SetWindowPos(hwnd, nullptr, 0, 0, startup_window_width_,
                       startup_window_height_, flags);
        const HWND view = flutter_controller_->view()->GetNativeWindow();
        ::RedrawWindow(view, nullptr, nullptr,
                       RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN);
        flutter_controller_->ForceRedraw();
      }
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
