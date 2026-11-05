import 'dart:async';

import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart' show mtLocalizationsFor;

import '../../di.dart';

/// One foreground service for everything that must go on after the user
/// leaves: downloads on the server, and the copy a share makes. Android
/// freezes an app in the background seconds after it leaves, so without
/// it a pull stops and starts again from nothing on return.
///
/// Each holder says whether it needs the service; it runs while any does.
/// Two owners switching one service would stop it under each other.
class BackgroundHold {
  BackgroundHold({required this.start, required this.stop});

  /// True when the service is running.
  final Future<bool> Function() start;
  final Future<void> Function() stop;

  final _holders = <String>{};
  bool _on = false;
  Future<void> _chain = Future.value();

  Future<void> set(String holder, bool needed) {
    needed ? _holders.add(holder) : _holders.remove(holder);
    return _chain = _chain.then((_) => _apply());
  }

  Future<void> _apply() async {
    final wanted = _holders.isNotEmpty;
    // A start that failed leaves it off, so the next call tries again.
    if (wanted == _on) return;
    if (wanted) {
      _on = await start();
    } else {
      await stop();
      _on = false;
    }
  }
}

final backgroundHoldProvider = Provider<BackgroundHold>((ref) {
  final logger = ref.watch(loggerProvider);
  return BackgroundHold(
    start: () async {
      try {
        final texts = mtLocalizationsFor(ref.read(settingsProvider).localeCode);
        final ready = await FlutterBackground.initialize(
          androidConfig: FlutterBackgroundAndroidConfig(
            notificationTitle: texts.downloadingTitle,
            notificationText: texts.backgroundDownload,
            notificationImportance: AndroidNotificationImportance.normal,
            notificationIcon: const AndroidResource(
              name: 'ic_stat_metube',
              defType: 'drawable',
            ),
            enableWifiLock: true,
            // No battery-optimisation exemption: an intrusive system dialog,
            // and the foreground service alone carries a download session.
            shouldRequestBatteryOptimizationsOff: false,
          ),
        );
        if (ready) await FlutterBackground.enableBackgroundExecution();
        return ready;
      } catch (e) {
        // A refused permission or an unsupported device: the work still
        // runs while the app is open, as it did before.
        await logger.error('background mode failed', cause: e, tag: 'download');
        return false;
      }
    },
    stop: () async {
      try {
        if (FlutterBackground.isBackgroundExecutionEnabled) {
          await FlutterBackground.disableBackgroundExecution();
        }
      } catch (e) {
        await logger.error('background mode failed', cause: e, tag: 'download');
      }
    },
  );
});
