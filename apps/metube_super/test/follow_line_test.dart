import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/home/link_preview_view.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/subscriptions/subscriptions_providers.dart';
import 'package:metube_super/features/subscriptions/widgets/follow_line.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show PlaylistItem;
import 'package:mt_ui/mt_ui.dart';

/// **Guard: "Follow" under a YouTube clip in the video player** (mobile
/// plan, stage 16/D). The server's history names no channel, so the
/// channel's address comes from YouTube's public oEmbed, and the follow
/// sheet opens with it filled in.
void main() {
  const oembed =
      '{"title":"Never Gonna Give You Up","author_name":"Rick Astley",'
      '"author_url":"https://www.youtube.com/@RickAstleyYT"}';

  PlaylistItem clip(String url) =>
      PlaylistItem(canonicalUrl: url, title: 'Clip', serverFilename: 'c.mp4');

  Future<List<Uri>> pump(
    WidgetTester tester, {
    required PlaylistItem item,
    String answer = oembed,
    List<ChannelSubscription> following = const [],
  }) async {
    final asked = <Uri>[];
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'http://nas.local:8081'),
        ),
        linkPreviewResolverProvider.overrideWithValue(
          ClipPreviewResolver(
            httpGet: (uri) async {
              asked.add(uri);
              return answer;
            },
          ),
        ),
        subscriptionsProvider.overrideWith(
          (ref) async => SubscriptionsState(subscriptions: following),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(body: FollowLine(item: item)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return asked;
  }

  testWidgets('**the guard**: a YouTube clip names its channel, and Follow '
      'opens the sheet with its link filled in', (tester) async {
    await pump(tester, item: clip('https://www.youtube.com/watch?v=abc'));
    expect(find.text('Rick Astley'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(find.text('https://www.youtube.com/@RickAstleyYT'), findsOneWidget);
  });

  testWidgets('a channel already followed says so instead', (tester) async {
    await pump(
      tester,
      item: clip('https://www.youtube.com/watch?v=abc'),
      following: const [
        ChannelSubscription(
          id: 'r',
          name: 'Rick Astley',
          url: 'https://www.youtube.com/@RickAstleyYT/',
          enabled: true,
          checkIntervalMinutes: 60,
        ),
      ],
    );
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('another site shows nothing and asks nobody', (tester) async {
    // Vimeo's oEmbed names a channel too, but the server follows YouTube.
    final asked = await pump(tester, item: clip('https://vimeo.com/76979871'));
    expect(find.text('Follow'), findsNothing);
    expect(asked, isEmpty);
  });

  testWidgets('an answer without the channel address shows nothing', (
    tester,
  ) async {
    await pump(
      tester,
      item: clip('https://www.youtube.com/watch?v=abc'),
      answer: '{"title":"Clip","author_name":"Someone"}',
    );
    expect(find.text('Someone'), findsNothing);
    expect(find.text('Follow'), findsNothing);
  });
}
