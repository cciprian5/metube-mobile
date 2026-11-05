import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';

/// The quality an add starts with, under the phone's own key so a backup
/// carries it either way. Audio starts the add on sound.
final defaultQualityProvider =
    NotifierProvider<DefaultQualityNotifier, Quality>(
      DefaultQualityNotifier.new,
    );

/// Read in main, so the first add after a start already has it.
final initialDefaultQualityProvider = Provider<Quality>((ref) => Quality.best);

class DefaultQualityNotifier extends Notifier<Quality> {
  static const key = 'video_quality';

  @override
  Quality build() => ref.watch(initialDefaultQualityProvider);

  Future<void> set(Quality quality) {
    state = quality;
    return ref
        .read(prefsMutexProvider)
        .run(
          () => ref.read(keyValueStoreProvider).setString(key, quality.wire),
        );
  }
}

/// Whether a notice says what the followed channels brought; on unless
/// turned off, under the phone's own key.
final notifyArrivalsProvider = NotifierProvider<NotifyArrivalsNotifier, bool>(
  NotifyArrivalsNotifier.new,
);

class NotifyArrivalsNotifier extends Notifier<bool> {
  static const key = 'notify_arrivals';

  @override
  bool build() {
    ref
        .read(keyValueStoreProvider)
        .getBool(key)
        .then((saved) => state = saved ?? true, onError: (_) {});
    return true;
  }

  Future<void> set(bool on) {
    state = on;
    return ref
        .read(prefsMutexProvider)
        .run(() => ref.read(keyValueStoreProvider).setBool(key, on));
  }
}

/// Whether a file downloaded to this computer opens Explorer on it when it
/// is done; off until chosen, as a window appearing by itself surprises.
final revealAfterDownloadProvider =
    NotifierProvider<RevealAfterDownloadNotifier, bool>(
      RevealAfterDownloadNotifier.new,
    );

class RevealAfterDownloadNotifier extends Notifier<bool> {
  static const key = 'ember_reveal_after_download';

  @override
  bool build() {
    ref
        .read(keyValueStoreProvider)
        .getBool(key)
        .then((saved) => state = saved ?? false, onError: (_) {});
    return false;
  }

  Future<void> set(bool on) {
    state = on;
    return ref
        .read(prefsMutexProvider)
        .run(() => ref.read(keyValueStoreProvider).setBool(key, on));
  }
}
