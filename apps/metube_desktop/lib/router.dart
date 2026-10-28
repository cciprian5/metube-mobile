import 'package:flutter/material.dart' show MaterialPage;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The settings sections: the phone app's, plus the two only a computer
/// has (the desktop habits, and the offline and download folders).
enum EmberSettingsPane {
  server,
  network,
  subscriptions,
  cookies,
  downloads,
  folders,
  appearance,
  desktop,
  transcripts,
  backup,
  sync,
  updates,
  logs,
  about;

  /// **Each section has its own address**, so a message about a problem
  /// can open the very page that fixes it.
  String get route => '/settings/$name';
}

/// The addresses of the app's places.
abstract final class EmberRoutes {
  static const library = '/library';

  /// Favourites and offline are the library seen through a filter, so the
  /// filter chips and these two sidebar entries are one state.
  static const favorites = '/library?only=favorites';
  static const offline = '/library?only=offline';
  static const search = '/search';
  static const playlists = '/playlists';
  static const channels = '/channels';
  static const settings = '/settings';

  /// The library counted: by site, channel and month.
  static const stats = '/stats';

  /// One clip's page. The key is a canonical URL, full of slashes and
  /// question marks, so it travels percent-encoded as one path segment.
  static String item(String canonicalUrl) =>
      '/item/${Uri.encodeComponent(canonicalUrl)}';

  /// One clip's reading room, its transcript as an article.
  static String reading(String canonicalUrl) =>
      '/read/${Uri.encodeComponent(canonicalUrl)}';

  /// One saved list's page, by its id.
  static String playlist(String id) => '$playlists/${Uri.encodeComponent(id)}';

  /// One followed channel's page, by the server's id for it.
  static String channel(String id) => '$channels/${Uri.encodeComponent(id)}';
}

/// The places the sidebar can show as current.
enum EmberPlace {
  library,
  favorites,
  offline,
  search,
  playlists,
  channels,
  settings,
  item,
}

/// Which place [location] is, for the sidebar's highlight.
EmberPlace placeOf(Uri location) {
  final first = location.pathSegments.firstOrNull;
  return switch (first) {
    'library' => switch (location.queryParameters['only']) {
      'favorites' => EmberPlace.favorites,
      'offline' => EmberPlace.offline,
      _ => EmberPlace.library,
    },
    'search' => EmberPlace.search,
    'playlists' => EmberPlace.playlists,
    'channels' => EmberPlace.channels,
    'settings' => EmberPlace.settings,
    // The library seen as figures: its place stays lit.
    'stats' => EmberPlace.library,
    _ => EmberPlace.item,
  };
}

/// Builds the shell around every place; the drawn shell replaces the
/// pass-through default.
typedef EmberShellBuilder = Widget Function(
  BuildContext context,
  GoRouterState state,
  Widget child,
);

Widget _bare(BuildContext context, GoRouterState state, Widget child) => child;

/// Builds a place from its query argument.
typedef EmberPlaceBuilder = Widget Function(String? argument);

Widget _pendingLibrary(String? only) => PendingPlace('library', argument: only);

Widget _pendingItem(String? canonicalUrl) =>
    PendingPlace('item', argument: canonicalUrl);

Widget _pendingReading(String? canonicalUrl) =>
    PendingPlace('read', argument: canonicalUrl);

Widget _pendingPlaylists(String? id) => PendingPlace('playlists', argument: id);

Widget _pendingChannels(String? id) => PendingPlace('channels', argument: id);

Widget _pendingStats(String? _) => const PendingPlace('stats');

Widget _pendingSettings(String? pane) =>
    PendingPlace('settings', argument: pane);

/// The single route table. One router per app, built once, so the shell
/// and the player under it live through every navigation.
GoRouter buildEmberRouter({
  String initialLocation = EmberRoutes.library,
  EmberShellBuilder shell = _bare,
  EmberPlaceBuilder library = _pendingLibrary,
  EmberPlaceBuilder item = _pendingItem,
  EmberPlaceBuilder reading = _pendingReading,
  EmberPlaceBuilder playlists = _pendingPlaylists,
  EmberPlaceBuilder channels = _pendingChannels,
  EmberPlaceBuilder settings = _pendingSettings,
  EmberPlaceBuilder stats = _pendingStats,
}) => GoRouter(
  initialLocation: initialLocation,
  // An address that names no place (an old link, a typo in a protocol
  // link) lands on the library rather than an error page.
  onException: (_, _, router) => router.go(EmberRoutes.library),
  routes: [
    GoRoute(path: '/', redirect: (_, _) => EmberRoutes.library),
    ShellRoute(
      builder: shell,
      routes: [
        GoRoute(
          path: EmberRoutes.library,
          builder: (_, state) => library(state.uri.queryParameters['only']),
        ),
        _place(EmberRoutes.search, 'search'),
        // A null argument is the place itself; an id is one list or one
        // channel in it.
        for (final (path, build) in [
          (EmberRoutes.playlists, playlists),
          (EmberRoutes.channels, channels),
        ])
          GoRoute(
            path: path,
            builder: (_, _) => build(null),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => build(state.pathParameters['id']),
              ),
            ],
          ),
        GoRoute(
          path: '/item/:id',
          builder: (_, state) => item(state.pathParameters['id']),
        ),
        GoRoute(
          path: '/read/:id',
          builder: (_, state) => reading(state.pathParameters['id']),
        ),
        GoRoute(path: EmberRoutes.stats, builder: (_, _) => stats(null)),
        // **One page for every section**, under one key: moving between
        // sections updates the page in place, so the list of sections
        // stays still and only the open section changes (with its own
        // fade, see SettingsPlace). As routes nested in one another, each
        // section was a new page sliding in whole.
        GoRoute(
          path: EmberRoutes.settings,
          pageBuilder: (_, _) => _settingsPage(settings(null)),
        ),
        GoRoute(
          path: '${EmberRoutes.settings}/:pane',
          // A section that does not exist names no place.
          redirect: (_, state) =>
              EmberSettingsPane.values.asNameMap().containsKey(
                state.pathParameters['pane'],
              )
              ? null
              : EmberRoutes.library,
          pageBuilder: (_, state) =>
              _settingsPage(settings(state.pathParameters['pane'])),
        ),
      ],
    ),
  ],
);

Page<void> _settingsPage(Widget child) =>
    MaterialPage(key: const ValueKey('settings'), child: child);

GoRoute _place(String path, String name) =>
    GoRoute(path: path, builder: (_, _) => PendingPlace(name));

/// Stands in for a place whose screen comes in a later step; it draws
/// nothing, and tests find it by [place] and [argument].
class PendingPlace extends StatelessWidget {
  const PendingPlace(this.place, {this.argument, super.key});

  final String place;
  final String? argument;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
