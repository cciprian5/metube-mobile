import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/shell/now_playing.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

/// **Guard: the player bar's square cover shows no black bands.** YouTube's
/// usual thumbnail is 4:3 with the picture between bands, which a square
/// box shows; the bar asks for the wide picture instead, as the phones do.
void main() {
  testWidgets('**the guard**: a YouTube clip playing takes the wide '
      'thumbnail in the bar, not the banded one', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    const url = 'https://www.youtube.com/watch?v=aaaaaaaaaaa';
    const banded = 'https://i.ytimg.com/vi/aaaaaaaaaaa/hqdefault.jpg';
    final clip = LibraryItem(
      canonicalUrl: url,
      title: 'Night Drive',
      onServer: true,
      serverFilename: 'Night Drive.mp4',
      thumbnail: banded,
      timestamp: DateTime(2026, 10, 20),
    );
    final h = ShellHarness(
      library: [clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([toPlaylistItem(clip)], playing: false);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(EmberNowPlaying),
        matching: find.text('Night Drive'),
      ),
      findsOneWidget,
    );
    final images = tester
        .widgetList<CachedNetworkImage>(
          find.descendant(
            of: find.byType(EmberNowPlaying),
            matching: find.byType(CachedNetworkImage),
          ),
        )
        .map((i) => i.imageUrl)
        .toList();
    expect(images, ['https://i.ytimg.com/vi/aaaaaaaaaaa/maxresdefault.jpg']);
    // It fills the square: left to its own 16:9 it sat in a band of the
    // card's colour, the bands moved rather than gone.
    final image = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byType(EmberNowPlaying),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(image.width, isNotNull);
    expect(image.width, image.height);
  });
}
