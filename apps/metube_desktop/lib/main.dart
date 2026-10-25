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
import 'data/addresses_data.dart';
import 'data/backup_data.dart';
import 'data/clip_handover.dart';
import 'data/copied_links.dart';
import 'data/covers/covers_data.dart';
import 'data/folders_data.dart';
import 'data/incoming_links.dart';
import 'data/lab_server.dart';
import 'data/setup_data.dart';
import 'data/transcripts_data.dart';
import 'features/add/add_entry.dart';
import 'features/library/artwork.dart';
import 'data/desktop_habits.dart';
import 'data/notices.dart';
import 'data/sync_runner.dart';
import 'data/system_media.dart';
import 'data/taskbar_data.dart';
import 'data/volume.dart';
import 'features/settings/whats_new.dart';
import 'di.dart';
import 'identity.dart';
import 'platform/clip_drag.dart';
import 'platform/clipboard_windows.dart';
import 'platform/link_drop.dart';
import 'platform/notifications.dart';
import 'platform/error_log.dart';
import 'platform/frame_grab.dart';
import 'platform/hotkeys.dart';
import 'platform/player_desktop.dart';
import 'platform/secret_store_windows.dart';
import 'platform/prefs_store.dart';
import 'platform/single_instance.dart';
import 'platform/video_surface_windows.dart';
import 'platform/window_controls_windows.dart';
import 'platform/window_frame.dart';
import 'platform/windows_folders.dart';
import 'platform/smtc.dart';
import 'platform/startup.dart';
import 'platform/taskbar.dart';
import 'platform/tray.dart';
import 'platform/volume_windows.dart';
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
  // A second start brings this window back, from the tray too; a
  // `metube://add` link it or the first start came with opens the add
  // dialog.
  final incoming = IncomingLinks();
  linksFromArgs(args).forEach(incoming.add);
  await claimSingleInstance(
    args,
    onSecondStart: (second) {
      unawaited(EmberWindow.bringBack());
      linksFromArgs(second).forEach(incoming.add);
    },
  );
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
  // The player is saved first; then whatever the app adds, such as the
  // sync folder's last write.
  final closing = <Future<void> Function()>[];
  // Off until chosen: closing the window closes the app.
  var toTray = await store.getBool(CloseToTray.key) ?? false;
  final window = await EmberWindow.open(
    placements: WindowPlacementStore(store: store, mutex: mutex),
    beforeClose: () async {
      await player.persist();
      for (final step in [...closing]) {
        await step();
      }
    },
    hideOnClose: () => toTray,
    zoom: wanted,
    // Started with Windows, the app keeps out of the way.
    start: !args.contains(WindowsStartup.arg)
        ? WindowStart.shown
        : toTray
        ? WindowStart.hidden
        : WindowStart.minimized,
  );
  // A size that did not fit this screen was stepped down; it is kept, and
  // the shell says so once.
  final lowered = window.zoom < wanted;
  if (lowered) await zooms.write(window.zoom);
  final controls = await WindowManagerControls.create();
  final notices = await WindowsNotices.start();
  // The app's own level, as it was left.
  final volume = MediaKitVolume(desktop.port.player);
  final keptVolume = await store.getInt(VolumeLevel.key);
  if (keptVolume != null) await volume.setLevel(keptVolume.toDouble());

  // Windows' places for the clip playing: the media keys and flyout, the
  // icon by the clock, the taskbar button. All read the player and command
  // it; none knows the engine.
  final labLocale = labLocaleFrom(args);
  final words = mtLocalizationsFor(labLocale);
  final tray = EmberTray(
    words: (
      play: words.play,
      pause: words.pause,
      next: words.next,
      open: words.desktopTrayOpen,
      quit: words.desktopTrayQuit,
    ),
    onOpen: () => unawaited(EmberWindow.bringBack()),
    onQuit: window.quit,
  );
  await tray.setOn(toTray);
  final taskbar = WindowsTaskbarSurface((
    previous: words.previous,
    play: words.play,
    pause: words.pause,
    next: words.next,
    downloads: words.activeDownloadsCount,
  ));
  final bridge = SystemMediaBridge(player, [
    ?await SmtcSurface.start(),
    tray,
    taskbar,
  ]);
  final startup = WindowsStartup();
  final startsWithWindows = await startup.isOn();
  final playKey = GlobalPlayHotKey(
    () => unawaited(bridge.press(SystemMediaButton.toggle)),
  );
  final playKeyOn = await store.getBool(GlobalPlayKey.key) ?? false
      ? await playKey.set(true)
      : false;
  // The lab file (debug builds) stands in for the first-run setup;
  // otherwise the server set up before, if any.
  const secrets = WindowsSecretStore();
  final setup =
      labServerFrom(args) ??
      await ServerSetupStore(
        store: store,
        secrets: secrets,
        mutex: mutex,
      ).read();
  final addresses = await AddressesStore(
    store: store,
    mutex: mutex,
  ).read(seed: [...labAddressesFrom(args), ?setup?.baseUrl]);
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
        clipDragProvider.overrideWith(
          (ref) =>
              (item, child) => ClipDragSource(
                item: item,
                handover: ref.read(clipHandoverProvider),
                child: child,
              ),
        ),
        incomingLinksProvider.overrideWithValue(incoming),
        initialShellLayoutProvider.overrideWithValue(layout),
        initialUiZoomProvider.overrideWithValue(
          UiZoom(window.zoom, lowered: lowered),
        ),
        windowControlsProvider.overrideWithValue(controls),
        initialServerSetupProvider.overrideWithValue(setup),
        offerSetupAtStartProvider.overrideWithValue(true),
        offerWhatsNewProvider.overrideWithValue(true),
        beforeCloseProvider.overrideWithValue(closing),
        initialCloseToTrayProvider.overrideWithValue(toTray),
        closeToTrayHookProvider.overrideWithValue((on) {
          toTray = on;
          unawaited(tray.setOn(on));
        }),
        taskbarPortProvider.overrideWithValue(taskbar),
        volumeControlProvider.overrideWithValue(volume),
        noticePortProvider.overrideWithValue(notices ?? const NoNotices()),
        windowInFrontProvider.overrideWithValue(EmberWindow.inFront),
        bringWindowBackProvider.overrideWithValue(EmberWindow.bringBack),
        initialStartWithWindowsProvider.overrideWithValue(startsWithWindows),
        startWithWindowsHookProvider.overrideWithValue(startup.set),
        initialGlobalPlayKeyProvider.overrideWithValue(playKeyOn),
        globalPlayKeyHookProvider.overrideWithValue(playKey.set),
        initialOfferCopiedLinksProvider.overrideWithValue(
          await store.getBool(OfferCopiedLinks.key) ?? false,
        ),
        clipboardPortProvider.overrideWithValue(WindowsClipboard()),
        backupFolderProvider.overrideWithValue(
          Directory('${roaming.path}/backup'),
        ),
        secretStoreProvider.overrideWithValue(secrets),
        initialAddressesProvider.overrideWithValue(addresses),
        desktopFoldersProvider.overrideWithValue(const WindowsFolders()),
        transcriptStoreProvider.overrideWithValue(
          TranscriptStore(Directory('${roaming.path}/transcripts')),
        ),
        artworkCacheProvider.overrideWithValue(
          artworkCacheIn('${local.path}/cache'),
        ),
        coverFolderProvider.overrideWithValue(
          Directory('${local.path}/cache/embedded'),
        ),
        frameGrabProvider.overrideWithValue(grabFrame),
      ],
      child: EmberApp(locale: labLocale == null ? null : Locale(labLocale)),
    ),
  );
}
