#include "flutter_window.h"

#include <commctrl.h>
#include <windowsx.h>

#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Snap Layouts with a title bar drawn by Flutter. Windows 11 offers the
// layouts only over a native maximize button, so the Dart title bar
// reports where its drawn button is; over that rectangle the Flutter view
// lets hit tests through to this window, which answers HTMAXBUTTON. Clicks
// and hover there then belong to Windows: the click is handled below and
// the hover is sent back so the drawn button can light up.

// Physical pixels in the Flutter view's client coordinates.
RECT g_max_rect = {0, 0, 0, 0};
HWND g_view = nullptr;

bool InMaxRect(LPARAM lparam) {
  if (!g_view || g_max_rect.right <= g_max_rect.left) return false;
  POINT p = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  ScreenToClient(g_view, &p);
  return PtInRect(&g_max_rect, p) != 0;
}

LRESULT CALLBACK ViewSubclass(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp,
                              UINT_PTR, DWORD_PTR) {
  if (msg == WM_NCHITTEST && InMaxRect(lp)) return HTTRANSPARENT;
  return DefSubclassProc(hwnd, msg, wp, lp);
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
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  g_view = flutter_controller_->view()->GetNativeWindow();
  SetWindowSubclass(g_view, ViewSubclass, 1, 0);
  snap_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "metube_ember/snap",
      &flutter::StandardMethodCodec::GetInstance());
  snap_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setMaxButtonRect") {
          const auto* l = std::get_if<flutter::EncodableList>(call.arguments());
          if (l && l->size() == 4) {
            g_max_rect = {std::get<int>((*l)[0]), std::get<int>((*l)[1]),
                          std::get<int>((*l)[2]), std::get<int>((*l)[3])};
          }
          result->Success();
        } else if (call.method_name() == "clientOrigin") {
          POINT p = {0, 0};
          ClientToScreen(g_view, &p);
          result->Success(flutter::EncodableValue(
              flutter::EncodableList{flutter::EncodableValue(static_cast<int>(p.x)),
                                     flutter::EncodableValue(static_cast<int>(p.y))}));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // The Dart side shows the window itself, where it was left and
    // maximized if it was; showing it "normal" here would undo that. This
    // stays only as a fallback for a start that failed before showing it,
    // and not for a start with Windows, which keeps the window in the tray
    // on purpose.
    const bool with_windows =
        std::wstring(::GetCommandLineW()).find(L"--startup") !=
        std::wstring::npos;
    if (!with_windows && !::IsWindowVisible(GetHandle())) {
      this->Show();
    }
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Before the plugins: window_manager answers WM_NCHITTEST for its own
  // resize edges and would swallow the maximise button.
  switch (message) {
    case WM_NCHITTEST:
      if (InMaxRect(lparam)) return HTMAXBUTTON;
      break;
    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        if (!max_hover_) {
          TRACKMOUSEEVENT t = {sizeof(t), TME_LEAVE | TME_NONCLIENT, hwnd, 0};
          TrackMouseEvent(&t);
          SetMaxHover(true);
        }
        return 0;
      }
      SetMaxHover(false);
      break;
    case WM_NCMOUSELEAVE:
      SetMaxHover(false);
      break;
    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        max_pressed_ = true;
        return 0;
      }
      break;
    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        if (max_pressed_) {
          ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
        }
        max_pressed_ = false;
        return 0;
      }
      break;
  }

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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetMaxHover(bool on) {
  if (on == max_hover_) return;
  max_hover_ = on;
  if (snap_channel_) {
    snap_channel_->InvokeMethod(
        "hover", std::make_unique<flutter::EncodableValue>(on));
  }
}
