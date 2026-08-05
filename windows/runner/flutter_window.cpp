#include "flutter_window.h"

#include <commctrl.h>

#include <cstdint>
#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/standard_method_codec.h>

#include "external_link_handler.h"
#include "secure_credential_store.h"

namespace {

constexpr UINT kForceStartupRedrawMessage = WM_APP + 1;
constexpr UINT_PTR kStartupResizeTimerId = 0x5646;
constexpr UINT kStartupResizeDelayMs = 75;
constexpr int kStartupResizeDelta = 32;
constexpr char kWindowChannelName[] = "ai.glosc.voxflow/window";
constexpr UINT_PTR kFlutterViewSubclassId = 0x56465852;

bool IsResizeHitTest(LRESULT hit_test) {
  switch (hit_test) {
    case HTLEFT:
    case HTRIGHT:
    case HTTOP:
    case HTTOPLEFT:
    case HTTOPRIGHT:
    case HTBOTTOM:
    case HTBOTTOMLEFT:
    case HTBOTTOMRIGHT:
      return true;
    default:
      return false;
  }
}

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
  flutter_view_handle_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(flutter_view_handle_);
  if (!::SetWindowSubclass(
          flutter_view_handle_, FlutterViewSubclassProc,
          kFlutterViewSubclassId, reinterpret_cast<DWORD_PTR>(this))) {
    flutter_view_handle_ = nullptr;
    return false;
  }
  flutter_view_subclass_installed_ = true;

  secure_credential_store_ = std::make_unique<SecureCredentialStore>(
      flutter_controller_->engine()->messenger());
  external_link_handler_ = std::make_unique<ExternalLinkHandler>(
      flutter_controller_->engine()->messenger());

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
        if (call.method_name() == "enableFrameless") {
          EnableFrameless();
          if (flutter_controller_) {
            const HWND view =
                flutter_controller_->view()->GetNativeWindow();
            const RECT client = GetClientArea();
            ::MoveWindow(view, client.left, client.top,
                         client.right - client.left,
                         client.bottom - client.top, TRUE);
            ::RedrawWindow(GetHandle(), nullptr, nullptr,
                           RDW_INVALIDATE | RDW_UPDATENOW | RDW_FRAME |
                               RDW_ALLCHILDREN);
            ::RedrawWindow(view, nullptr, nullptr,
                           RDW_INVALIDATE | RDW_UPDATENOW);
            flutter_controller_->ForceRedraw();
          }
          // The first Flutter frame can be presented before the native frame
          // transition has reached DWM. Queue the existing compositor nudge
          // again after switching to frameless mode so startup never remains
          // white until the user opens the system menu or resizes the window.
          ::PostMessage(GetHandle(), kForceStartupRedrawMessage, 0, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "minimize") {
          ::ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "maximizeOrRestore") {
          ::ShowWindow(GetHandle(), ::IsZoomed(GetHandle()) ? SW_RESTORE
                                                            : SW_MAXIMIZE);
          result->Success();
          return;
        }
        if (call.method_name() == "close") {
          ::PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        if (call.method_name() == "startDrag") {
          POINT cursor{};
          ::GetCursorPos(&cursor);
          ::ReleaseCapture();
          ::PostMessage(GetHandle(), WM_NCLBUTTONDOWN, HTCAPTION,
                        MAKELPARAM(cursor.x, cursor.y));
          result->Success();
          return;
        }
        if (call.method_name() == "isMaximized") {
          result->Success(flutter::EncodableValue(
              static_cast<bool>(::IsZoomed(GetHandle()))));
          return;
        }
        if (call.method_name() == "getVersion") {
          result->Success(flutter::EncodableValue(std::string(FLUTTER_VERSION)));
          return;
        }
        if (call.method_name() == "setBrightness") {
          const auto* brightness =
              std::get_if<std::string>(call.arguments());
          if (!brightness) {
            result->Error("invalid_argument", "Brightness must be a string.");
            return;
          }
          SetDarkMode(*brightness == "dark");
          result->Success();
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
  external_link_handler_.reset();
  secure_credential_store_.reset();
  window_channel_.reset();
  if (flutter_view_subclass_installed_ && flutter_view_handle_) {
    ::RemoveWindowSubclass(flutter_view_handle_, FlutterViewSubclassProc,
                           kFlutterViewSubclassId);
  }
  flutter_view_subclass_installed_ = false;
  flutter_view_handle_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT CALLBACK FlutterWindow::FlutterViewSubclassProc(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam,
    UINT_PTR subclass_id, DWORD_PTR reference_data) noexcept {
  if (message == WM_NCHITTEST) {
    auto* that = reinterpret_cast<FlutterWindow*>(reference_data);
    if (that && that->GetHandle()) {
      const LRESULT parent_hit_test = ::SendMessage(
          that->GetHandle(), WM_NCHITTEST, wparam, lparam);
      if (IsResizeHitTest(parent_hit_test)) {
        // HTTRANSPARENT asks User32 to continue hit-testing windows from the
        // same UI thread underneath the Flutter child. The native parent then
        // receives the non-client mouse messages that start system resizing.
        return HTTRANSPARENT;
      }
    }
  }

  return ::DefSubclassProc(window, message, wparam, lparam);
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
