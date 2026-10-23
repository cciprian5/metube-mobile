import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/library_data.dart';
import '../di.dart';
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

    return Material(
      color: p.bg,
      child: LayoutBuilder(
        builder: (context, box) {
          final arranged = arrangeShell(box.maxWidth, layout);
          final panelShown = arranged.panelBeside
              ? !layout.panelHidden
              : _overlayOpen;
          final panel = StreamBuilder<MTPlayerState>(
            stream: player.states,
            initialData: player.state,
            builder: (context, snap) => EmberRightPanel(
              tab: _tab,
              onTab: (tab) => setState(() => _tab = tab),
              state: snap.data ?? player.state,
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
                      current: placeOf(widget.location),
                      onGo: router.go,
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
                                if (!arranged.panelBeside && _overlayOpen) ...[
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
                    if (arranged.panelBeside && !layout.panelHidden) panel,
                  ],
                ),
              ),
              EmberPlayerBar(
                player: player,
                onShowQueue: () => _showTab(PanelTab.upNext, arranged),
              ),
            ],
          );
        },
      ),
    );
  }
}
