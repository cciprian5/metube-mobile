import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/covers/covers_data.dart';
import '../data/library_data.dart';
import '../data/lists_data.dart';
import '../di.dart';
import '../features/add/add_dialog.dart';
import '../features/add/add_entry.dart';
import '../features/clip/clip_state.dart';
import '../features/folders/folder_tree.dart';
import '../features/library/library_state.dart';
import '../router.dart';
import 'content_bar.dart';
import 'nav_history.dart';
import 'player_bar.dart';
import 'right_panel.dart';
import 'shell_layout.dart';
import 'shell_metrics.dart';
import 'shell_state.dart';
import 'sidebar.dart';
import 'title_bar.dart';

/// The window's frame around every place: title bar, sidebar, content,
/// side panel and the player bar. Built once for the life of the app (it
/// is the router's shell), so nothing it holds restarts on navigation.
class EmberShell extends ConsumerStatefulWidget {
  const EmberShell({super.key, required this.location, required this.child});

  final Uri location;
  final Widget child;

  @override
  ConsumerState<EmberShell> createState() => _EmberShellState();
}

/// The id of the saved list whose page [location] is, if it is one.
String? _openList(Uri location) => switch (location.pathSegments) {
  ['playlists', final id] => id,
  _ => null,
};

class _EmberShellState extends ConsumerState<EmberShell> {
  NavHistory? _history;
  PanelTab _tab = PanelTab.transcript;

  /// The panel as a layer over the content, in a narrow window only. Not
  /// saved: a layer left open would cover the content on the next start.
  bool _overlayOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= NavHistory.of(GoRouter.of(context));
  }

  @override
  void dispose() {
    _history?.dispose();
    super.dispose();
  }

  void _togglePanel(ShellArrangement arranged, ShellLayout layout) {
    if (arranged.panelBeside) {
      ref
          .read(shellLayoutProvider.notifier)
          .setPanelHidden(!layout.panelHidden);
    } else {
      setState(() => _overlayOpen = !_overlayOpen);
    }
  }

  void _showTab(PanelTab tab, ShellArrangement arranged) {
    setState(() {
      _tab = tab;
      if (!arranged.panelBeside) _overlayOpen = true;
    });
    if (arranged.panelBeside) {
      ref.read(shellLayoutProvider.notifier).setPanelHidden(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final layout = ref.watch(shellLayoutProvider);
    final player = ref.watch(playerProvider);
    final controls = ref.watch(windowControlsProvider);
    final router = GoRouter.of(context);
    ref.watch(playbackWiringProvider);
    ref.watch(sessionRestoreProvider);
    ref.watch(coverEnrichmentProvider);

    // Theater widens a clip's picture over the side panel's column too.
    final theater =
        ref.watch(theaterProvider) &&
        placeOf(widget.location) == EmberPlace.item;
    EmberPlayerBar playerBar(ShellArrangement? arranged) => EmberPlayerBar(
      player: player,
      onShowQueue: () => arranged == null
          ? controls.setFullScreen(false)
          : _showTab(PanelTab.upNext, arranged),
      onOpen: (url) => router.go(EmberRoutes.item(url)),
    );

    final drop = ref.watch(linkDropProvider);
    // A Scaffold underneath, so notices (`showMTNotice`) have somewhere to
    // appear, above the player bar.
    final scaffold = Scaffold(
      backgroundColor: p.bg,
      body: ValueListenableBuilder<bool>(
        valueListenable: controls.fullScreen,
        builder: (context, full, _) => full
            // The whole screen for the picture; the player bar stays, so
            // the clip can still be paused and sought.
            ? Column(
                children: [
                  Expanded(child: widget.child),
                  playerBar(null),
                ],
              )
            : _framed(context, layout, theater, playerBar),
      ),
    );
    // Links reach the add dialog three ways: the button, Ctrl+V anywhere
    // but a text field, and a drop on the window.
    return AddShortcut(onLinks: _openAdd, child: drop(scaffold, _openAdd));
  }

  void _openAdd([String text = '']) =>
      unawaited(openAddDialog(context, text: text));

  /// The button offers what the clipboard holds, as the phone's does.
  Future<void> _addFromButton() async {
    final text = await clipboardLinks();
    if (mounted) _openAdd(text);
  }

  Widget _framed(
    BuildContext context,
    ShellLayout layout,
    bool theater,
    EmberPlayerBar Function(ShellArrangement) playerBar,
  ) {
    final player = ref.read(playerProvider);
    final controls = ref.read(windowControlsProvider);
    final router = GoRouter.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final arranged = arrangeShell(box.maxWidth, layout);
        final place = placeOf(widget.location);
        final folder = ref.watch(libraryViewProvider).folder;
        final panelShown =
            !theater &&
            (arranged.panelBeside ? !layout.panelHidden : _overlayOpen);
        final panel = StreamBuilder<MTPlayerState>(
          stream: player.states,
          initialData: player.state,
          builder: (context, snap) => EmberRightPanel(
            tab: _tab,
            onTab: (tab) => setState(() => _tab = tab),
            state: snap.data ?? player.state,
            player: player,
          ),
        );
        return Column(
          children: [
            EmberTitleBar(controls: controls),
            Expanded(
              child: Row(
                children: [
                  EmberSidebar(
                    narrow: arranged.sidebarNarrow,
                    current: place,
                    pinned: ref.watch(pinnedPlaylistsProvider),
                    currentList: _openList(widget.location),
                    folders: sidebarFolders(
                      ref.watch(libraryItemsProvider).valueOrNull ?? const [],
                      folder,
                    ),
                    currentFolder: place == EmberPlace.library ? folder : null,
                    onFolder: (path) {
                      // The chosen folder again goes up a level.
                      final view = ref.read(libraryViewProvider.notifier);
                      view.setFolder(
                        path == folder && place == EmberPlace.library
                            ? parentFolder(path)
                            : path,
                      );
                      router.go(EmberRoutes.library);
                    },
                    onGo: router.go,
                    onAdd: () => unawaited(_addFromButton()),
                    onToggleNarrow: arranged.canWidenSidebar
                        ? () => ref
                              .read(shellLayoutProvider.notifier)
                              .setSidebarNarrow(!layout.sidebarNarrow)
                        : null,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        EmberContentBar(
                          history: _history!,
                          onSearch: () => router.go(EmberRoutes.search),
                          panelShown: panelShown,
                          onTogglePanel: () => _togglePanel(arranged, layout),
                        ),
                        // The layer opens over the content only, so the
                        // bar with its own toggle stays reachable.
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: widget.child),
                              if (!arranged.panelBeside &&
                                  _overlayOpen &&
                                  !theater) ...[
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _overlayOpen = false),
                                  ),
                                ),
                                PositionedDirectional(
                                  top: 0,
                                  bottom: 0,
                                  end: 0,
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      boxShadow: MTShadow.card,
                                    ),
                                    child: panel,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (arranged.panelBeside && panelShown) panel,
                ],
              ),
            ),
            playerBar(arranged),
          ],
        );
      },
    );
  }
}
