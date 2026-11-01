import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../home/add_flow.dart';
import '../shared/error_text.dart';
import '../player/playback_providers.dart';
import '../settings/settings_sections.dart';
import 'library_providers.dart';
import 'local_item.dart';
import 'media_access.dart';
import 'widgets/media_access_view.dart';
import 'widgets/downloads_sheet.dart';
import 'widgets/task_card_parts.dart';
import 'widgets/library_cards.dart';
import 'widgets/library_app_bars.dart';
import 'widgets/library_chips.dart';

/// "My downloads", the local library: live cards only while something is
/// active, plus a counter badge in the header that opens the management
/// sheet. Search is always visible.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// The highlight from a completion-notification tap is **temporary**. It
  /// used to be set and never cleared, so the item kept a "selected" look
  /// forever (field report 2026-09-02).
  static const highlightDuration = Duration(seconds: 6);
  Timer? _highlightTimer;

  /// The search field is open in the bar's place.
  bool _searchOpen = false;

  void _clearHighlight() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    if (ref.read(highlightedItemProvider) != null) {
      ref.read(highlightedItemProvider.notifier).state = null;
    }
  }

  @override
  void initState() {
    super.initState();
    // The first screen is where the media permission is asked; the reason
    // is with [ensureMediaAccessOnStart].
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ensureMediaAccessOnStart(ref)),
    );
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    ref.listen<String?>(highlightedItemProvider, (_, next) {
      _highlightTimer?.cancel();
      if (next == null) return;
      _highlightTimer = Timer(highlightDuration, () {
        if (mounted) _clearHighlight();
      });
    });
    final options = ref.watch(libraryViewProvider);
    final active = ref.watch(activeTasksProvider);
    final settings = ref.watch(settingsProvider);

    // The library is local and works with no server, so the empty state
    // invites configuration only when there is no server **and no files**.
    final items = ref.watch(localMediaProvider).valueOrNull ?? const [];
    final needsSetup = !settings.isConfigured && items.isEmpty;

    final searching = _searchOpen || options.query.isNotEmpty;
    void closeSearch() {
      setState(() => _searchOpen = false);
      ref.read(libraryViewProvider.notifier).setQuery('');
    }

    // Back closes the search first, rather than leaving the app.
    return PopScope(
      canPop: !searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) closeSearch();
      },
      child: Scaffold(
        // Selecting swaps the bar with a short fade rather than a cut.
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: MTAnimatedSwap(
            child: KeyedSubtree(
              key: ValueKey(options.selecting),
              child: options.selecting
                  ? librarySelectionBar(context, ref, options)
                  : libraryMainBar(
                      context,
                      ref,
                      activeCount: active.length,
                      searching: searching,
                      onSearch: () => setState(() => _searchOpen = true),
                      onCloseSearch: closeSearch,
                    ),
            ),
          ),
        ),
        body: needsSetup
            ? MTEmptyState(
                title: l10n.noServerTitle,
                message: l10n.noServerMessage,
                actionLabel: l10n.setupServer,
                onAction: () => context.go(SettingsPane.server.route),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  // A failed refresh is shown by the library itself in its
                  // empty state, and
                  // rethrowing here escapes the `RefreshIndicator` with
                  // nobody to catch
                  // it.
                  ref.invalidate(localMediaProvider);
                  try {
                    await ref.read(localMediaProvider.future);
                  } on MTApiException {
                    // Shown in the empty state.
                  }
                },
                // One calm appearance of the content on the first build,
                // rather than motion per card, which made the list bounce
                // throughout the scroll.
                // A wide grid gains columns, and a tablet spreads every mode
                // across its width; a phone's rows and cards keep theirs.
                child: MTRevealOnce(
                  child:
                      options.mode == LibraryViewMode.grid ||
                          MTAdaptiveScaffold.hasRail(context)
                      ? _body(l10n, options, active)
                      : MTReadableWidth(child: _body(l10n, options, active)),
                ),
              ),
      ),
    );
  }

  /// **Lazy building is mandatory** (a performance lesson from phase 6):
  /// the header is a sliver and the items are a `SliverList.builder` that
  /// builds only what is visible.
  Widget _body(
    MTLocalizations l10n,
    LibraryViewOptions options,
    List<DownloadTask> active,
  ) {
    final itemsAsync = ref.watch(visibleLibraryProvider);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
          sliver: SliverList.list(
            children: [
              const SizedBox(height: MTSpace.xs),
              const LibraryFilterChips(),
              const SizedBox(height: MTSpace.md),
              ..._activeStrip(l10n, active),
            ],
          ),
        ),
        // **The order of the cases is deliberate** (field report
        // 2026-09-02): every library invalidation passes through
        // `AsyncLoading` **while keeping the previous data**, and matching
        // that first replaced the list with a spinner for a fraction of a
        // second, a continuous flicker during downloads, when the library
        // refreshes repeatedly. Existing data always wins, and a spinner
        // appears only on the very first load.
        ...switch (itemsAsync) {
          AsyncValue(valueOrNull: final value?) when value.isNotEmpty => [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              // No "where is it" column: every item here is on the device.
              sliver: MTLibrarySliver(
                layout: options.mode.layout,
                itemCount: value.length,
                itemBuilder: (context, index, columns) =>
                    _itemCard(value[index], columns),
              ),
            ),
          ],
          // The page keeps its shape while the first answer comes.
          AsyncLoading() => [
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: MTSpace.pagePad),
              sliver: MTRowsSkeleton(),
            ),
          ],
          // The message comes from the error itself rather than from a
          // fixed string (the same cure as Super).
          // A folder Android refuses to read is not an error to report but
          // a permission to ask for, and it has its own screen.
          AsyncError(error: MediaAccessDeniedException()) => [
            const SliverToBoxAdapter(child: MediaAccessView()),
          ],
          AsyncError(:final error) => [
            SliverToBoxAdapter(
              child: MTEmptyState(
                title: l10n.tryAgain,
                message: errorText(l10n, error),
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(localMediaProvider),
              ),
            ),
          ],
          AsyncValue(valueOrNull: final value?) when value.isEmpty => [
            SliverToBoxAdapter(
              // **Say why it is empty**, as in Super: a filter that hides
              // everything is not an empty library.
              child: switch (options) {
                LibraryViewOptions(query: final q) when q.isNotEmpty =>
                  MTEmptyState(
                    title: l10n.noResults,
                    message: l10n.noResultsMessage,
                  ),
                LibraryViewOptions(narrowed: true) => MTEmptyState(
                  title: l10n.emptyFilteredTitle,
                  message: l10n.emptyFilteredMessage,
                ),
                _ => MTEmptyState(
                  title: l10n.noDownloads,
                  message: l10n.noDownloadsMessage,
                ),
              },
            ),
          ],
          _ => const <Widget>[],
        },
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }

  /// **One task shows its full card; more than one collapses into a single
  /// summary line.**
  ///
  /// Field report 2026-09-03: "several downloads all appear in the
  /// downloads library while a button for them already sits in the header.
  /// Find a way to stop them crowding one place."
  List<Widget> _activeStrip(MTLocalizations l10n, List<DownloadTask> active) {
    if (active.isEmpty) return const [];
    return [
      if (active.length == 1)
        _taskCard(l10n, active.first)
      else
        MTActiveDownloadsBar(
          label: l10n.activeDownloadsCount(active.length),
          actionLabel: l10n.viewAll,
          progress: averageTaskProgress(active),
          onTap: () => showDownloadsSheet(context),
        ),
      const SizedBox(height: MTSpace.sm),
    ];
  }

  Widget _taskCard(MTLocalizations l10n, DownloadTask task) {
    final engine = ref.read(downloadEngineProvider);
    final statusText = switch (task.phase) {
      TaskPhase.queued => l10n.queuedSection,
      // Rule 4: tapping an item. Audio plays in the background immediately
      // and
      // the mini player appears; video opens `/player`. The internal play
      // queue
      // is **the library as displayed** at the moment of the tap, with the
      // same
      // sorting and filtering.
      TaskPhase.adding || TaskPhase.polling => l10n.onServerPhase,
      TaskPhase.waitingForNetwork => l10n.waitingForWifi,
      TaskPhase.pulling => l10n.pullingToDevice,
      // Lite cleans the server after pulling, a short phase that deserves
      // to be named explicitly.
      TaskPhase.deleting => l10n.cleaningServer,
      TaskPhase.failed => taskErrorText(l10n, task),
      _ => l10n.completed,
    };
    return MTDownloadProgressCard(
      key: ValueKey('${task.id}-${task.phase.name}'),
      title: task.title ?? task.effectiveUrl,
      thumbnail: taskThumbnail(task),
      detail: taskSpeed(task),
      waiting: task.phase == TaskPhase.queued,
      statusText: statusText,
      progress: task.hasKnownProgress ? task.progress : null,
      isError: task.phase == TaskPhase.failed,
      onCancel: () => engine?.cancel(task.id),
    );
  }

  /// Rule 4: tapping an item. Audio plays in the background immediately;
  /// video opens `/player`, and a short portrait clip opens reels. The
  /// internal play queue is **the library as displayed** at the moment of
  /// the tap, with the same sorting and filtering.
  Future<void> _play(LocalItem tapped) async {
    final visible = ref.read(visibleLibraryProvider).valueOrNull ?? const [];
    final items = [for (final item in visible) toPlaylistItem(item)];
    final index = visible.indexWhere((i) => i.key == tapped.key);
    if (items.isEmpty || index < 0) return;

    if (tapped.isAudio) {
      await ref.read(audioHandlerProvider).playItems(items, startIndex: index);
      return;
    }
    ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: items,
      startIndex: index,
    );
    if (!mounted) return;
    context.push(tapped.isShortForm ? '/reels' : '/player');
  }

  /// The card reads the mode from the options itself; it is not passed
  /// twice.
  Widget _itemCard(LocalItem item, MTMediaColumns? columns) => LibraryItemCard(
    item: item,
    columns: columns,
    onPlay: () => _play(item),
    onClearHighlight: _clearHighlight,
  );
}
