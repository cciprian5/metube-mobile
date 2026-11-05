import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/copied_links.dart';
import 'package:metube_desktop/data/desktop_habits.dart';
import 'package:metube_desktop/data/notices.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

/// Windows' clipboard, copied into by the test.
class _Clipboard implements ClipboardPort {
  void Function(String text)? _onCopy;
  bool get watching => _onCopy != null;

  void copy(String text) => _onCopy?.call(text);

  @override
  void start(void Function(String text) onCopy) => _onCopy = onCopy;

  @override
  void stop() => _onCopy = null;
}

class _Notices implements NoticePort {
  final shown = <EmberNotice>[];

  @override
  Future<void> show(EmberNotice notice) async => shown.add(notice);
}

void main() {
  group('the link worth offering', () {
    const kept = ['https://www.youtube.com/watch?v=kept0000000'];

    test('**the guard**: the first link of a known site; other text and '
        'unknown sites are passed over', () {
      expect(
        linkToOffer(
          'see https://example.com/page and https://youtu.be/abcdefghijk '
          'then https://vimeo.com/1',
          offered: const [],
          library: const [],
        ),
        'https://youtu.be/abcdefghijk',
      );
      for (final text in ['hunter2', 'https://example.com/x', '']) {
        expect(
          linkToOffer(text, offered: const [], library: const []),
          isNull,
          reason: text,
        );
      }
    });

    test('**the guard**: never offered twice, nor what the library has, in '
        'any spelling of the same link', () {
      expect(
        linkToOffer(
          'https://youtu.be/abcdefghijk',
          offered: const ['https://www.youtube.com/watch?v=abcdefghijk'],
          library: const [],
        ),
        isNull,
      );
      expect(
        linkToOffer(
          'https://youtu.be/kept0000000',
          offered: const [],
          library: kept,
        ),
        isNull,
      );
    });
  });

  group('in the app', () {
    Future<(ShellHarness, _Clipboard, _Notices)> open(
      WidgetTester tester, {
      bool on = true,
      bool inFront = false,
    }) async {
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
      final clipboard = _Clipboard();
      final notices = _Notices();
      final h = ShellHarness(
        library: [
          LibraryItem(
            canonicalUrl: 'https://www.youtube.com/watch?v=kept0000000',
            title: 'Kept',
            onServer: true,
            serverFilename: 'Kept.mp4',
          ),
        ],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [
          initialOfferCopiedLinksProvider.overrideWithValue(on),
          clipboardPortProvider.overrideWithValue(clipboard),
          noticePortProvider.overrideWithValue(notices),
          windowInFrontProvider.overrideWithValue(() async => inFront),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return (h, clipboard, notices);
    }

    testWidgets('**the guard**: off until chosen, the clipboard is not even '
        'watched', (tester) async {
      final (_, clipboard, _) = await open(tester, on: false);
      expect(clipboard.watching, isFalse);
    });

    testWidgets('**the guard**: a link copied elsewhere is offered once; its '
        'button opens the add dialog on it and sends nothing', (tester) async {
      final (h, clipboard, notices) = await open(tester);
      clipboard
        ..copy('https://youtu.be/abcdefghijk')
        ..copy('https://youtu.be/abcdefghijk')
        ..copy('https://youtu.be/kept0000000');
      await tester.pumpAndSettle();
      final [notice] = notices.shown;
      expect(notice.title, 'Add this link to the server?');
      expect(notice.body, 'https://youtu.be/abcdefghijk');

      notice.actions.single.onPressed();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'https://youtu.be/abcdefghijk'),
        findsOneWidget,
      );
      expect(h.engine.submitted, isEmpty);
    });

    testWidgets('a copy made with the window in front is left to Ctrl+V', (
      tester,
    ) async {
      final (_, clipboard, notices) = await open(tester, inFront: true);
      clipboard.copy('https://youtu.be/abcdefghijk');
      await tester.pumpAndSettle();
      expect(notices.shown, isEmpty);
    });
  });
}
