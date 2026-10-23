import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import 'shell/shell_layout.dart';

/// Riverpod injection, as in the phone apps: what needs the disk or the
/// engine is built once in main and handed in through overrides.

/// Overridden in main once SharedPreferences is ready.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// One lock for all storage, shared by everyone rather than created twice.
final prefsMutexProvider = Provider((ref) => PrefsMutex());

/// The diagnostic log; overridden in main with its path.
final loggerProvider = Provider<MTLogger>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// Overridden in main. The server address is wired into it when the
/// server settings arrive, as on the phone.
final playbackResolverProvider = Provider<PlaybackSourceResolver>(
  (ref) => throw UnimplementedError('overridden in main'),
);

/// The one player, overridden in main: the interface, the media keys and
/// the tray all talk to this and never to the engine.
final playerProvider = Provider<MTPlayer>(
  (ref) => throw UnimplementedError('overridden in main'),
);

final shellLayoutStoreProvider = Provider(
  (ref) => ShellLayoutStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);
