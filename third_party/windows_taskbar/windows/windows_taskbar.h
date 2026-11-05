/// This file is a part of windows_taskbar
/// (https://github.com/alexmercerind/windows_taskbar).
///
/// Copyright (c) 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the
/// LICENSE file.

#ifndef WINDOWS_TASKBAR_H_
#define WINDOWS_TASKBAR_H_

#include <ShObjIdl.h>
#include <Windows.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

struct ThumbnailToolbarButton {
  std::string icon;
  std::string tooltip;
  int32_t mode;
};

class WindowsTaskbar {
 public:
  static constexpr auto kMinThumbButtonID = 40001;
  static constexpr auto kMaxThumbButtonCount = 7;

  WindowsTaskbar(HWND window);

  ~WindowsTaskbar();

  bool SetProgressMode(int32_t mode);

  bool SetProgress(int32_t completed, int32_t total);

  bool SetThumbnailToolbar(std::vector<ThumbnailToolbarButton> buttons);

  bool ResetThumbnailToolbar();

  bool SetThumbnailTooltip(std::string tooltip);

  bool SetFlashTaskbarAppIcon(int32_t mode, int32_t flash_count,
                              int32_t timeout);

  bool ResetFlashTaskbarAppIcon();

  bool SetOverlayIcon(std::string icon, std::string tooltip);

  bool ResetOverlayIcon();

  bool SetWindowTitle(std::string title);

  bool ResetWindowTitle();

  bool IsTaskbarVisible();

  // Windows sends "TaskbarButtonCreated" each time it makes the window's
  // taskbar button: when the window is first shown, when it is shown again
  // after being hidden, and when Explorer restarts. Thumbnail buttons, the
  // progress bar and the overlay belong to that button, so they are added
  // again here from what was last asked for.
  void OnTaskbarButtonCreated();

 private:
  bool ApplyThumbnailToolbar();
  bool ApplyProgress();
  bool ApplyOverlayIcon();

  HWND window_ = nullptr;
  ITaskbarList3* taskbar_ = nullptr;
  // True once the taskbar button exists; calls before then are kept and
  // applied when it does, since ITaskbarList3 rejects them until then.
  bool button_ready_ = false;
  bool thumb_buttons_added_ = false;
  std::vector<ThumbnailToolbarButton> thumb_buttons_;
  int32_t progress_mode_ = TBPF_NOPROGRESS;
  int32_t progress_completed_ = 0;
  int32_t progress_total_ = 0;
  bool progress_known_ = false;
  std::string overlay_icon_;
  std::string overlay_tooltip_;
  std::unique_ptr<wchar_t[]> window_title_ = nullptr;
};

#endif
