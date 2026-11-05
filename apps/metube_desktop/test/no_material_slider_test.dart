import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_desktop/features/clip/video_controls.dart';
import 'package:metube_desktop/router.dart';
import 'package:metube_desktop/shell/ember_slider.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

/// Material's `Slider` keeps its value bubble's overlay always shown, and
/// on Windows that overlay's accessibility node reached the engine with
/// no parent: the accessibility bridge took it for the root, failed every
/// update after, and crashed the app some seconds into a session. The
/// app's sliders are [EmberSlider], which has no overlay.
void main() {
  test('**the guard**: no Material Slider in lib', () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            RegExp(r'(?<![A-Za-z])(Range)?Slider\(')
                .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  testWidgets('**the guard**: a video playing on its page draws no Material '
      'Slider, in the bar or over the picture', (tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    const url = 'https://youtu.be/aaaaaaaaaaa';
    final clip = LibraryItem(
      canonicalUrl: url,
      title: 'Night Drive',
      onServer: true,
      serverFilename: 'Night Drive.mp4',
      timestamp: DateTime(2026, 10, 20),
    );
    final h = ShellHarness(
      library: [clip],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.player.showPlaying([toPlaylistItem(clip)], playing: false);
    GoRouter.of(tester.element(find.byType(EmberSidebar)))
        .go(EmberRoutes.item(url));
    await tester.pumpAndSettle();
    expect(find.byType(ClipVideoControls), findsOneWidget);
    expect(find.byType(EmberSlider), findsNWidgets(3));
    expect(find.byType(Slider), findsNothing);
  });
}
