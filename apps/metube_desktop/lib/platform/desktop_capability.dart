import 'dart:io';

/// What this machine **can** do. Detected once at start-up and passed down;
/// a widget asks this rather than `Platform`, so every branch can be tested
/// on any machine by building the capability by hand.
class DesktopCapability {
  const DesktopCapability({
    required this.isWindows,
    required this.windowsBuild,
  });

  /// Reads the running system. The only place in the app that looks at
  /// [Platform].
  factory DesktopCapability.detect() => DesktopCapability(
    isWindows: Platform.isWindows,
    windowsBuild: parseWindowsBuild(Platform.operatingSystemVersion),
  );

  final bool isWindows;

  /// The Windows build number, or 0 when it could not be read.
  final int windowsBuild;

  /// The first Windows 10 build. The system media controls arrived with
  /// it; Flutter itself needs no less, so in practice this only fails on a
  /// version string we could not read.
  static const int windows10 = 10240;

  /// Progress on the taskbar button: every Windows Flutter runs on.
  bool canShowTaskbarProgress() => isWindows;

  /// The system media overlay and the keyboard's media keys.
  bool canUseSmtc() => isWindows && windowsBuild >= windows10;

  /// Dragging a clip out of the window as a file, to Explorer or the
  /// desktop.
  bool canDragFilesOut() => isWindows;

  /// `"Windows 10 Pro" 10.0 (Build 26200)` -> 26200; anything else -> 0.
  static int parseWindowsBuild(String version) =>
      int.tryParse(
        RegExp(r'Build (\d+)').firstMatch(version)?.group(1) ?? '',
      ) ??
      0;
}
