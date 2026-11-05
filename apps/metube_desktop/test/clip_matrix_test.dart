import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/ui_zoom.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'desktop_matrix.dart';
import 'support/shell_harness.dart';

// A clip's page through the window matrix: a video with its actions and a
// short in its 9:16 column, with long titles in both scripts.

const _video = 'https://youtu.be/aaaaaaaaaaa';
const _short = 'https://youtu.be/sssssssssA1';

final _library = [
  LibraryItem(
    canonicalUrl: _video,
    title:
        'Homelab Hour - Ep. 12: snapshots, replication and why a second box '
        'in another room is the only backup that counts',
    uploader: 'Homelab Hour with a rather long channel name',
    onServer: true,
    timestamp: DateTime(2026, 10, 22),
    sizeBytes: 100,
    duration: const Duration(hours: 1, minutes: 12),
  ),
  LibraryItem(
    canonicalUrl: _short,
    title:
        'ساعة المختبر المنزلي: لماذا لا تُعدّ نسخة احتياطية إلا تلك التي في '
        'جهاز آخر',
    uploader: 'قناة المختبر',
    onServer: true,
    timestamp: DateTime(2026, 10, 23),
    sizeBytes: 100,
    duration: const Duration(seconds: 40),
    aspectRatio: 0.56,
  ),
];

void main() {
  for (final (url, name) in [(_video, 'a video'), (_short, 'a short')]) {
    for (final zoom in [1.0, 0.8, 1.5]) {
      testWidgets('the page of $name, at ${(zoom * 100).round()}%', (
        tester,
      ) async {
        late ShellHarness h;
        final item = _library.firstWhere((i) => i.canonicalUrl == url);
        await expectNoOverflow(
          tester,
          () => (h = ShellHarness(
            library: _library,
            server: ServerConfig(baseUrl: 'http://nas:8081'),
            zoom: UiZoom(zoom),
          )).app(),
          windows: zoom == 1.0
              ? EmberWindowSize.all
              : [
                  EmberWindowSize(
                    'smallest at ${(zoom * 100).round()}%',
                    const Size(960, 600) * zoom,
                  ),
                ],
          then: (tester) async {
            // Paused: a playing card's equalizer never settles.
            h.player.showPlaying([toPlaylistItem(item)], playing: false);
            await tester.pumpAndSettle();
            await tester.tap(find.text(item.title).first);
          },
        );
      });
    }
  }
}
