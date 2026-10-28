import 'package:flutter/material.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/context_menu.dart';
import '../../shell/player_controls.dart';

/// The library's order, as the phone's sort sheet offers it: newest,
/// oldest, by name either way, largest or smallest. Every layout has it;
/// the table's headers sort too, and both keep the same choice.
class SortButton extends StatelessWidget {
  const SortButton({super.key, required this.sort, required this.onSort});

  final LibrarySort sort;
  final ValueChanged<LibrarySort> onSort;

  static String labelOf(MTLocalizations l, LibrarySort sort) => switch (sort) {
    LibrarySort.newest => l.sortNewest,
    LibrarySort.oldest => l.sortOldest,
    LibrarySort.nameAZ => l.sortNameAZ,
    LibrarySort.nameZA => l.sortNameZA,
    LibrarySort.largest => l.sortLargest,
    LibrarySort.smallest => l.sortSmallest,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return Builder(
      builder: (context) => EmberPlayerControl(
        icon: MTIcons.sort,
        label: '${l.sortBy} · ${labelOf(l, sort)}',
        onTap: () async {
          // Opened under the button, as a menu from a toolbar is.
          final box = context.findRenderObject()! as RenderBox;
          final at = box.localToGlobal(box.size.bottomCenter(Offset.zero));
          final picked = await showEmberMenu<LibrarySort>(context, at, [
            for (final s in LibrarySort.values)
              EmberMenuEntry(
                s,
                s == sort ? MTIcons.check : null,
                labelOf(l, s),
              ),
          ]);
          if (picked != null && picked != sort) onSort(picked);
        },
      ),
    );
  }
}
