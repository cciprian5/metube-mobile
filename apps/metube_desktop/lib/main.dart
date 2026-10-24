import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/covers/covers_data.dart';
import 'data/lab_server.dart';
import 'data/library_data.dart';
import 'data/transcripts_data.dart';
import 'features/add/add_entry.dart';
import 'features/library/artwork.dart';
import 'di.dart';
import 'identity.dart';
import 'platform/link_drop.dart';
import 'platform/error_log.dart';
import 'platform/player_desktop.dart';
import 'platform/prefs_store.dart';
import 'platform/single_instance.dart';
import 'platform/video_surface_windows.dart';
import 'platform/window_controls_windows.dart';
import 'platform/window_frame.dart';
import 'platform/window_placement.dart';
import 'shell/shell_layout.dart';
import 'shell/shell_state.dart';
import 'shell/ui_zoom.dart';
import 'shell/video_surface.dart';

/// Bootstrap only: one copy, storage, the player, the window, runApp.
///
/// `--gallery` opens the Wahaj component sheet instead, with `--night` and
/// `--ltr` for the other theme and direction.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerMTIconLicenses();
  if (args.contains('--gallery')) {
    runApp(
      EmberGalleryApp(
        night: args.contains('--night'),
        arabic: !args.contains('--ltr'),
      ),
    );
    return;
  }
  // First, before anything opens a file or a window: a second copy exits
  // here and the first comes to the front.
  await claimSingleInstance(args);
  initMTL10n();
  MediaKit.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final store = SharedPrefsKeyValueStore(prefs);
  final mutex = PrefsMutex();
  final local = await getApplicationCacheDirectory();
  final roaming = await getApplicationSupportDirectory();
  final logger = MTLogger(
    filePath: '${local.path}/logs/${EmberIdentity.logFile}',
  );
  logEveryError(logger);

  final resolver = PlaybackSourceResolver(endpoint: ServerStreamEndpoint.none);
  final desktop = DesktopPlayer.create(
    resolver: resolver,
    store: store,
    mutex: mutex,
  );
  final player = desktop.session;
  await player.loadPreferences();
  // The last queue comes back once the shell has wired the server in
  // (sessionRestoreProvider), not here.

  final layout = await ShellLayoutStore(store: store, mutex: mutex).read();
  final zooms = UiZoomStore(store: store, mutex: mutex);
  final wanted = await zooms.read();
  final window = await EmberWindow.open(
    placements: WindowPlacementStore(store: store, mutex: mutex),
    beforeClose: player.persist,
    zoom: wanted,
  );
  // A size that did not fit this screen was stepped down; it is kept, and
  // the shell says so once.
  final lowered = window.zoom < wanted;
  if (lowered) await zooms.write(window.zoom);
  final controls = await WindowManagerControls.create();
  unawaited(logger.log('app started (ember)', tag: 'app'));

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(mutex),
        loggerProvider.overrideWithValue(logger),
        playbackResolverProvider.overrideWithValue(resolver),
        playerProvider.overrideWithValue(player),
        videoSurfaceProvider.overrideWithValue(
          MediaKitVideoSurface(desktop.port.player),
        ),
        linkDropProvider.overrideWithValue(
          (child, onText) => LinkDropArea(onText: onText, child: child),
        ),
        initialShellLayoutProvider.overrideWithValue(layout),
        initialUiZoomProvider.overrideWithValue(
          UiZoom(window.zoom, lowered: lowered),
        ),
        windowControlsProvider.overrideWithValue(controls),
        serverConfigProvider.overrideWithValue(labServerFrom(args)),
        transcriptStoreProvider.overrideWithValue(
          TranscriptStore(Directory('${roaming.path}/transcripts')),
        ),
        artworkCacheProvider.overrideWithValue(
          artworkCacheIn('${local.path}/cache'),
        ),
        coverFolderProvider.overrideWithValue(
          Directory('${local.path}/cache/embedded'),
        ),
      ],
      child: const EmberApp(),
    ),
  );
}
