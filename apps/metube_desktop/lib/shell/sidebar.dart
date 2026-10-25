import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart' show SavedPlaylist;
import 'package:mt_ui/mt_ui.dart';

import '../data/saved_searches.dart';
import '../features/folders/folder_tree.dart';
import '../router.dart';
import 'shell_metrics.dart';
import 'sidebar_items.dart';

/// The sidebar: adding a link on top, the places, then settings at the
/// foot. 240 wide with labels, or 72 with icons alone and the labels in
/// tooltips.
class EmberSidebar extends StatelessWidget {
  const EmberSidebar({
    super.key,
    required this.narrow,
    required this.current,
    required this.onGo,
    this.onAdd,
    this.onToggleNarrow,
    this.pinned = const [],
    this.currentList,
    this.folders = const [],
    this.currentFolder,
    this.onFolder,
    this.searches = const [],
    this.onSavedSearch,
    this.onSavedSearchMenu,
  });

  /// The saved searches, under "Search", each opening the palette on its
  /// query.
  final List<SavedSearch> searches;
  final ValueChanged<SavedSearch>? onSavedSearch;
  final void Function(SavedSearch search, Offset at)? onSavedSearchMenu;

  final bool narrow;
  final EmberPlace current;
  final ValueChanged<String> onGo;

  /// null until the add dialog exists; the button stays, dimmed.
  final VoidCallback? onAdd;

  /// null when the window is too narrow to offer the wide sidebar.
  final VoidCallback? onToggleNarrow;

  /// The pinned lists, under "Playlists", each a place of its own.
  final List<SavedPlaylist> pinned;

  /// The id of the list whose page is open, if one is.
  final String? currentList;

  /// The server folders the library's clips sit in, unfolded along the
  /// chosen one; a click filters the library by it.
  final List<SidebarFolder> folders;

  /// The folder the library is filtered by, when the library is on show.
  final String? currentFolder;
  final ValueChanged<String>? onFolder;

  /// The places' width inside the wide sidebar's padding.
  static const _wideInside = EmberShellSize.sidebarWide - 2 * _pad;
  static const _pad = MTSpace.md;

  /// The hairline at its edge, which the container keeps out of the places
  /// too, and a little more for rounding.
  static const _border = 2.0;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return AnimatedContainer(
      duration: MTMotion.medium,
      curve: MTMotion.ease,
      width: narrow ? EmberShellSize.sidebarNarrow : EmberShellSize.sidebarWide,
      decoration: BoxDecoration(
        color: p.bg,
        border: BorderDirectional(end: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.all(_pad),
      // Widening, the places keep their narrow form until the sidebar has
      // room for their names: laid out wide in a width still growing, a
      // line with a count ran over its end (the window's own resizing
      // widens it too).
      child: LayoutBuilder(
        builder: (context, box) =>
            _places(context, narrow || box.maxWidth < _wideInside - _border),
      ),
    );
  }

  Widget _places(BuildContext context, bool narrow) {
    final l = context.mtl;
    final onPinned = pinned.any((list) => list.id == currentList);
    Widget item(EmberPlace place, MTIconData icon, String label, String to) =>
        SidebarItem(
          icon: icon,
          label: label,
          narrow: narrow,
          selected: current == place && !onPinned,
          onTap: () => onGo(to),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SidebarAddButton(narrow: narrow, label: l.addLinkFab, onTap: onAdd),
        const SizedBox(height: MTSpace.lg),
        // The places scroll, so pinned lists never push settings off a
        // short window.
        Expanded(
          child: ListView(
            children: [
              item(
                EmberPlace.library,
                MTIcons.library,
                l.navLibrary,
                EmberRoutes.library,
              ),
              item(
                EmberPlace.favorites,
                MTIcons.favorite,
                l.favorites,
                EmberRoutes.favorites,
              ),
              item(
                EmberPlace.offline,
                MTIcons.download,
                l.filterOffline,
                EmberRoutes.offline,
              ),
              item(
                EmberPlace.search,
                MTIcons.search,
                l.desktopSearch,
                EmberRoutes.search,
              ),
              for (final search in searches)
                SidebarItem(
                  key: ValueKey('search-${search.id}'),
                  icon: MTIcons.search,
                  label: search.name,
                  narrow: narrow,
                  indent: true,
                  selected: false,
                  onTap: () => onSavedSearch?.call(search),
                  onMenu: onSavedSearchMenu == null
                      ? null
                      : (at) => onSavedSearchMenu!(search, at),
                ),
              const SizedBox(height: MTSpace.lg),
              item(
                EmberPlace.playlists,
                MTIcons.queue,
                l.navPlaylists,
                EmberRoutes.playlists,
              ),
              for (final list in pinned)
                SidebarItem(
                  key: ValueKey('pinned-${list.id}'),
                  icon: MTIcons.queue,
                  label: list.name,
                  narrow: narrow,
                  indent: true,
                  selected: list.id == currentList,
                  onTap: () => onGo(EmberRoutes.playlist(list.id)),
                ),
              item(
                EmberPlace.channels,
                MTIcons.subscriptions,
                l.desktopChannels,
                EmberRoutes.channels,
              ),
              if (folders.isNotEmpty && onFolder != null) ...[
                const SizedBox(height: MTSpace.lg),
                for (final folder in folders)
                  // Narrow, only the top level: icons alone cannot show
                  // nesting.
                  if (!narrow || folder.depth == 0)
                    SidebarItem(
                      key: ValueKey('folder-${folder.path}'),
                      icon: MTIcons.folder,
                      label: mtName(folder.path.split('/').last),
                      trailing: '${folder.count}',
                      narrow: narrow,
                      depth: folder.depth,
                      selected: folder.path == currentFolder,
                      onTap: () => onFolder!(folder.path),
                    ),
              ],
            ],
          ),
        ),
        if (onToggleNarrow case final toggle?)
          SidebarItem(
            icon: MTIcons.collapse,
            label: narrow ? l.desktopWidenSidebar : l.desktopNarrowSidebar,
            narrow: narrow,
            selected: false,
            onTap: toggle,
          ),
        item(
          EmberPlace.settings,
          MTIcons.settings,
          l.navSettings,
          EmberRoutes.settings,
        ),
      ],
    );
  }
}
