import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/transcripts_data.dart';
import '../router.dart';
import '../shell/player_bar.dart';
import '../shell/right_panel.dart';
import '../shell/shell_metrics.dart';
import '../shell/sidebar.dart';
import '../shell/title_bar.dart';
import '../shell/window_controls.dart';
import 'still_player.dart';

// The shell's parts on their own, for the widget previewer
// (`flutter widget-preview start` in this folder, or the IDE's preview
// tab). Each comes in day and night, English and Arabic, as the app ships.
// Only the drawn widgets: nothing from `platform/`, which needs Windows,
// while the previewer runs in a browser.

/// Day and night, in both reading directions.
final class EmberPreview extends MultiPreview {
  const EmberPreview(this.name, {this.size});

  final String name;
  final Size? size;

  @override
  List<Preview> get previews => [
    for (final (wrapper, language) in [
      (inEnglish, 'English'),
      (inArabic, 'Arabic'),
    ])
      for (final brightness in Brightness.values)
        Preview(
          group: 'Ember shell',
          name: '$name - $language, ${brightness.name}',
          size: size,
          wrapper: wrapper,
          brightness: brightness,
        ),
  ];
}

Widget inEnglish(Widget child) => _InEmber(const Locale('en'), child);
Widget inArabic(Widget child) => _InEmber(const Locale('ar'), child);

/// What the app puts around its pages: the desktop theme for the
/// previewer's brightness, the language, and a transcript to show.
class _InEmber extends StatelessWidget {
  const _InEmber(this.locale, this.child);

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return MTDesktopApp(
      child: ProviderScope(
        overrides: [
          transcriptForProvider.overrideWith((ref, key) async => _transcript),
        ],
        child: Theme(
          data: mtDesktopTheme(MTVariant.superApp, brightness),
          child: Localizations(
            locale: locale,
            delegates: MTLocalizations.localizationsDelegates,
            child: Builder(
              builder: (context) => Material(
                color: MTThemeX.of(context).palette.bg,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _url = 'https://youtu.be/aaaaaaaaaaa';

final _queue = [
  const PlaylistItem(
    canonicalUrl: _url,
    title: 'Homelab Hour - Ep. 12: snapshots are not backups',
    uploader: 'Homelab Hour',
    serverFilename: 'Homelab Hour [aaaaaaaaaaa].mp4',
    duration: Duration(minutes: 41, seconds: 5),
  ),
  const PlaylistItem(
    canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
    title: 'ساعة المختبر المنزلي: النسخ الاحتياطي في جهاز آخر',
    uploader: 'قناة المختبر',
    isAudio: true,
    duration: Duration(minutes: 12),
  ),
  const PlaylistItem(
    canonicalUrl: 'https://www.tiktok.com/@a/video/1',
    title: 'Tidepools at Dawn',
    uploader: 'Field Notes',
    duration: Duration(seconds: 48),
  ),
];

final _transcript = Transcript(
  canonicalUrl: _url,
  language: 'en',
  source: 'sidecar',
  fetchedAt: DateTime(2026, 10, 24),
  segments: [
    for (final (s, text) in [
      (0, 'First rule: a snapshot on the same pool is not a backup.'),
      (20, 'If the pool dies, the snapshots go with it.'),
      (40, 'So we replicate the snapshots to a second box every night.'),
      (60, 'And once a month, one copy leaves the house.'),
    ])
      TranscriptSegment(
        start: Duration(seconds: s),
        end: Duration(seconds: s + 19),
        text: text,
      ),
  ],
);

final _playing = MTPlayerState(
  items: _queue,
  ordered: _queue,
  index: 0,
  playing: true,
  phase: MediaPlaybackState.ready,
  duration: const Duration(minutes: 41, seconds: 5),
);

void _ignore([Object? _]) {}

@EmberPreview('Title bar', size: Size(1280, EmberShellSize.titleBar))
Widget titleBarPreview() => EmberTitleBar(controls: InertWindowControls());

@EmberPreview('Sidebar, wide', size: Size(EmberShellSize.sidebarWide, 640))
Widget sidebarPreview() => EmberSidebar(
  narrow: false,
  current: EmberPlace.library,
  onGo: _ignore,
  onToggleNarrow: _ignore,
);

@EmberPreview('Sidebar, narrow', size: Size(EmberShellSize.sidebarNarrow, 640))
Widget sidebarNarrowPreview() => EmberSidebar(
  narrow: true,
  current: EmberPlace.offline,
  onGo: _ignore,
  onToggleNarrow: _ignore,
);

@EmberPreview('Player bar, playing', size: Size(1280, EmberShellSize.playerBar))
Widget playerBarPreview() => EmberPlayerBar(
  player: StillPlayer(_playing, const Duration(minutes: 7, seconds: 12)),
  onShowQueue: _ignore,
  onOpen: _ignore,
  onMini: _ignore,
  audioOnly: false,
  listening: false,
  onListen: _ignore,
);

@EmberPreview('Player bar, idle', size: Size(1280, EmberShellSize.playerBar))
Widget playerBarIdlePreview() => EmberPlayerBar(
  player: StillPlayer(),
  onShowQueue: _ignore,
  onOpen: _ignore,
  onMini: _ignore,
  audioOnly: false,
  listening: false,
  onListen: _ignore,
);

Widget _panel(PanelTab tab, MTPlayerState state) => EmberRightPanel(
  tab: tab,
  onTab: _ignore,
  state: state,
  player: StillPlayer(state, const Duration(seconds: 25)),
);

@EmberPreview('Panel, transcript', size: Size(EmberShellSize.panel, 640))
Widget panelTranscriptPreview() => _panel(PanelTab.transcript, _playing);

@EmberPreview('Panel, up next', size: Size(EmberShellSize.panel, 640))
Widget panelUpNextPreview() => _panel(PanelTab.upNext, _playing);

@EmberPreview('Panel, details', size: Size(EmberShellSize.panel, 640))
Widget panelDetailsPreview() => _panel(PanelTab.details, _playing);

@EmberPreview('Panel, nothing playing', size: Size(EmberShellSize.panel, 640))
Widget panelIdlePreview() => _panel(PanelTab.transcript, const MTPlayerState());

/// Every preview above, for the test that keeps them building.
final List<Widget Function()> shellPreviews = [
  titleBarPreview,
  sidebarPreview,
  sidebarNarrowPreview,
  playerBarPreview,
  playerBarIdlePreview,
  panelTranscriptPreview,
  panelUpNextPreview,
  panelDetailsPreview,
  panelIdlePreview,
];
