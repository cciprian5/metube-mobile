# windows_taskbar 1.1.2, patched

A copy of [windows_taskbar](https://pub.dev/packages/windows_taskbar) 1.1.2
(MIT, see `LICENSE`), used by the Windows app through `dependency_overrides`
in the workspace `pubspec.yaml`. The `example/` folder of the original is
left out. Only `windows/` changed; the Dart API is the same.

## The change: wait for the taskbar button, and follow it

`ITaskbarList3` works on the window's taskbar button, which Windows makes
some moments after the window is shown, and announces with the registered
message `TaskbarButtonCreated`. The original ignored that message:

- A call made before the button existed failed. For the thumbnail toolbar
  that was permanent: the failed `ThumbBarAddButtons` still marked the
  buttons as added, so every later call used `ThumbBarUpdateButtons` on
  buttons that were never there, and the toolbar under the window's
  preview never appeared.
- Windows makes a new button when a hidden window is shown again (an app
  that closes to the tray) and when Explorer restarts. The new button has
  no thumbnail buttons, progress or overlay, and the original never put
  them back.

The patch keeps the last thumbnail buttons, progress and overlay asked for,
applies them only once the button exists and the window is visible, and
applies them again on every `TaskbarButtonCreated`. A failed add no longer
counts as added. Icons loaded for the toolbar and the overlay are freed
after the taskbar has copied them; the original leaked one per call.
