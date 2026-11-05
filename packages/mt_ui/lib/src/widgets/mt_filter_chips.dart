import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icon_data.dart';
import '../icons/mt_icons.dart';

/// One active filter at the head of the chip row, with its way out.
///
/// The filters a sheet holds (platform, folder, tags) would otherwise be
/// invisible once the sheet closes, and the library would simply look half
/// empty. A name from the server can be long; the row scrolls, but one chip
/// must not own all of it.
class MTActiveFilterChip extends StatelessWidget {
  const MTActiveFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
    this.icon,
    this.onPressed,
    this.struck = false,
  });

  final String label;
  final MTIconData? icon;
  final VoidCallback onDeleted;

  /// Usually reopens the sheet the filter was chosen in.
  final VoidCallback? onPressed;

  /// An excluded tag: drawn struck through, so subtraction never reads as
  /// addition at a glance.
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final bg = MTThemeX.of(context).palette.bg;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: MTSpace.xs),
      child: InputChip(
        avatar: icon == null ? null : MTIcon(icon!, size: 15, color: bg),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        selected: true,
        showCheckmark: false,
        onDeleted: onDeleted,
        deleteIcon: const MTIcon(MTIcons.close, size: 16),
        deleteIconColor: bg,
        onPressed: onPressed,
        labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: bg,
          decoration: struck ? TextDecoration.lineThrough : null,
          decorationColor: bg,
        ),
      ),
    );
  }
}

/// The header button that opens the sort and filter sheet, with a dot while
/// a filter chosen inside it is on: the chip row shows which, and the dot
/// says where to change it.
class MTFilterButton extends StatelessWidget {
  const MTFilterButton({
    super.key,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return IconButton(
      tooltip: active ? '$tooltip · ${context.mtl.filtersOn}' : tooltip,
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: active,
        smallSize: 7,
        backgroundColor: p.accent,
        child: const MTIcon(MTIcons.sort),
      ),
    );
  }
}

/// A chip arriving in a row, such as a tag chosen in the filter sheet:
/// **it widens from nothing** and the chips after it make room, rather than
/// the row jumping by a chip's width. Give it a key per chip, so the chips
/// already there do not arrive again.
class MTGrowIn extends StatefulWidget {
  const MTGrowIn({super.key, required this.child});

  final Widget child;

  @override
  State<MTGrowIn> createState() => _MTGrowInState();
}

class _MTGrowInState extends State<MTGrowIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: MTMotion.medium,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _grow,
    curve: MTMotion.entrance,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_grow.isAnimating || _grow.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _grow.value = 1;
    } else {
      _grow.forward();
    }
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curved,
    axis: Axis.horizontal,
    alignment: AlignmentDirectional.centerStart,
    child: FadeTransition(opacity: _curved, child: widget.child),
  );
}
