import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/data/desktop_habits.dart';
import 'package:metube_desktop/data/system_media.dart';
import 'package:metube_desktop/data/taskbar_data.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:mt_media/mt_media.dart';

import 'support/shell_harness.dart';

/// A Windows place that records what it was told to show.
class _Surface implements SystemMediaSurface {
  final shown = <SystemNowPlaying?>[];
  final presses = StreamController<SystemMediaButton>.broadcast();

  @override
  Stream<SystemMediaButton> get buttons => presses.stream;

  @override
  Future<void> show(SystemNowPlaying? now) async => shown.add(now);

  @override
  Future<void> dispose() => presses.close();
}

/// The taskbar, recording what it was told.
class _Taskbar implements TaskbarPort {
  final shown = <TaskbarDownloads>[];

  @override
  Future<void> showDownloads(TaskbarDownloads downloads) async =>
      shown.add(downloads);
}

PlaylistItem _clip(String title, {String? art}) => PlaylistItem(
  canonicalUrl: 'https://youtu.be/$title',
  title: title,
  uploader: 'Field Notes',
  artworkUrl: art,
);

void main() {
  group('the cover Windows may fetch', () {
    test("**the guard**: a cover on the user's own server never goes to "
        'Windows; YouTube\'s public ones do', () {
      expect(
        publicThumbnail('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
        isNotNull,
      );
      for (final private in [
        'http://192.168.1.10:8081/thumbnails/a.jpg',
        'https://metube.example.com/download/a.jpg',
        'https://me:secret@i.ytimg.com/vi/abc/hq.jpg',
        'http://i.ytimg.com/vi/abc/hq.jpg',
        null,
      ]) {
        expect(publicThumbnail(private), isNull, reason: '$private');
      }
    });
  });

  group("Windows' own right to left", () {
    test('**the guard**: a mirrored taskbar is handed the preview buttons '
        'reversed, so they read ⏮ ▶ ⏭ like the player bar', () {
      expect(windowsMirrors('ar'), isTrue);
      expect(windowsMirrors('en'), isFalse);
      expect(windowsMirrors(null), isFalse);
      const buttons = ['previous', 'play', 'next'];
      expect(previewOrder(buttons, mirrored: true), [
        'next',
        'play',
        'previous',
      ]);
      expect(previewOrder(buttons, mirrored: false), buttons);
    });

    test("**the guard**: an Arabic tray line is embedded right to left, so "
        "the verb comes before the app's name; English is left alone", () {
      final arabic = windowsMenuText('فتح MeTube Ember', rtl: true);
      expect(arabic.runes.first, 0x202B);
      expect(arabic.runes.last, 0x202C);
      expect(
        windowsMenuText('Open MeTube Ember', rtl: false),
        'Open MeTube Ember',
      );
    });
  });

  test('**the guard**: the taskbar plugin is the patched copy that waits '
      'for the taskbar button and follows it after the tray', () {
    final lines = [
      for (final line in File('../../pubspec.yaml').readAsLinesSync())
        line.trim(),
    ];
    final at = lines.indexOf('windows_taskbar:');
    expect(at, isNot(-1));
    expect(lines[at + 1], 'path: third_party/windows_taskbar');
    final native = File(
      '../../third_party/windows_taskbar/windows/windows_taskbar_plugin.cc',
    ).readAsStringSync();
    expect(native, contains('TaskbarButtonCreated'));
  });

  group('the bridge', () {
    test('**the guard**: each place is told once per change, and every '
        "place's buttons command the one player", () async {
      final player = FakePlayer();
      final media = _Surface();
      final tray = _Surface();
      final bridge = SystemMediaBridge(player, [media, tray]);
      addTearDown(bridge.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(media.shown, [null]);

      player.showPlaying([
        _clip('Night Drive', art: 'https://i.ytimg.com/vi/a/hq.jpg'),
        _clip('Blue Hour'),
      ]);
      player.showPlaying([
        _clip('Night Drive', art: 'https://i.ytimg.com/vi/a/hq.jpg'),
        _clip('Blue Hour'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(media.shown, hasLength(2));
      final now = media.shown.last!;
      expect(
        (now.title, now.artist, now.playing, now.canNext),
        ('Night Drive', 'Field Notes', true, true),
      );
      expect(tray.shown.last, now);

      tray.presses.add(SystemMediaButton.toggle);
      media.presses.add(SystemMediaButton.next);
      await Future<void>.delayed(Duration.zero);
      expect(player.calls, ['pause', 'next']);
    });
  });

  group('the taskbar', () {
    testWidgets('**the guard**: it counts what is under way, and a waiting '
        'download shows a moving bar, not 0%', (tester) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      final taskbar = _Taskbar();
      final h = ShellHarness(
        library: const [],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [taskbarPortProvider.overrideWithValue(taskbar)],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(taskbar.shown.last, (count: 0, progress: null));

      final first = h.engine.submit(
        'https://youtu.be/aaaaaaaaaaa',
        Quality.best,
      );
      await tester.pumpAndSettle();
      expect(taskbar.shown.last, (count: 1, progress: null));

      h.engine.advance(first, 0.4);
      h.engine.submit('https://youtu.be/bbbbbbbbbbb', Quality.best);
      await tester.pumpAndSettle();
      expect(taskbar.shown.last, (count: 2, progress: 0.4));

      h.engine.finish(first);
      await tester.pumpAndSettle();
      expect(taskbar.shown.last.count, 1);
    });
  });

  group('keep playing in the tray', () {
    testWidgets('**the guard**: off until chosen; turning it on tells the '
        'window and is kept', (tester) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final told = <bool>[];
      final h = ShellHarness(
        library: const [],
        overrides: [closeToTrayHookProvider.overrideWithValue(told.add)],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(EmberSidebar)))
          .go('/settings/desktop');
      await tester.pumpAndSettle();
      // The tray line is the first of the section.
      final toggle = find.byType(MTSwitch).first;
      expect(
        find.text('Keep playing in the tray when the window closes'),
        findsOneWidget,
      );
      expect(tester.widget<MTSwitch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(told, [true]);
      expect(await h.store.getBool(CloseToTray.key), isTrue);
      expect(
        ProviderScope.containerOf(tester.element(find.byType(EmberSidebar)))
            .read(closeToTrayProvider),
        isTrue,
      );
    });
  });
}
