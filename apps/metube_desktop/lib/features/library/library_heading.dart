import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../router.dart';
import '../../shell/player_controls.dart';
import 'sort_button.dart';

/// The library's heading, **held at the top while the list scrolls**: the
/// title and counts, the sort, the figures and the layouts stay in reach
/// in the middle of a long library, as a file explorer's toolbar does.
/// The filters below it scroll away; two rows of chips held too would eat
/// the window.
///
/// A hairline comes in under it once something has scrolled beneath, so
/// the edge shows only when there is something to separate.
class PinnedLibraryHeading extends StatefulWidget {
  const PinnedLibraryHeading({super.key, required this.child});

  final Widget child;

  @override
  State<PinnedLibraryHeading> createState() => _PinnedLibraryHeadingState();
}

class _PinnedLibraryHeadingState extends State<PinnedLibraryHeading> {
  ScrollPosition? _position;
  bool _under = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position?..addListener(_onScroll);
  }

  void _onScroll() {
    final under = (_position?.pixels ?? 0) > 0;
    if (under != _under) setState(() => _under = under);
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return AnimatedContainer(
      duration: mtMotionDuration(context, MTMotion.tap),
      curve: MTMotion.entrance,
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.sm,
        MTSpace.xl,
        MTSpace.sm,
      ),
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(
          bottom: BorderSide(
            color: _under ? p.line2 : p.line2.withValues(alpha: 0),
            width: MTThemeX.of(context).hairline,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}

/// The title and its counts, then the sort, the figures and the layouts.
class LibraryHeading extends StatelessWidget {
  const LibraryHeading({
    super.key,
    required this.title,
    required this.counts,
    required this.mode,
    required this.onMode,
    required this.sort,
    required this.onSort,
  });

  final String title;
  final String? counts;
  final LibraryViewMode mode;
  final ValueChanged<LibraryViewMode> onMode;
  final LibrarySort sort;
  final ValueChanged<LibrarySort> onSort;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l = context.mtl;
    // The title and its counts wrap under each other when the window or
    // the font leaves no room; the layout choice keeps its place.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
            spacing: MTSpace.md,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(title, style: text.headlineSmall),
              if (counts case final line?) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: MTSpace.xxs),
                  child: Text(
                    line,
                    style: text.bodySmall?.copyWith(color: p.ink3),
                  ),
                ),
              ],
            ],
          ),
        ),
        // The figures behind the counts, a page of their own; then the
        // layouts, each a glyph with its name under the mouse.
        if (counts != null) ...[
          SortButton(sort: sort, onSort: onSort),
          EmberPlayerControl(
            icon: MTIcons.stats,
            label: l.desktopStatsLink,
            onTap: () => GoRouter.of(context).go(EmberRoutes.stats),
          ),
          const SizedBox(width: MTSpace.sm),
        ],
        for (final (m, icon, label) in [
          (LibraryViewMode.grid, MTIcons.grid, l.viewGrid),
          (LibraryViewMode.list, MTIcons.table, l.desktopViewTable),
          (LibraryViewMode.compact, MTIcons.list, l.desktopViewCompact),
        ])
          EmberPlayerControl(
            icon: icon,
            label: label,
            selected: mode == m,
            onTap: () => onMode(m),
          ),
      ],
    );
  }
}

/// A sliver that fades in afresh whenever [value] changes: a new layout,
/// order or filter shows as the list arriving, not as a jump. Only the
/// incoming list fades, once; scrolling never animates anything.
class SliverFadeOnChange extends StatefulWidget {
  const SliverFadeOnChange({
    super.key,
    required this.value,
    required this.sliver,
  });

  final Object value;
  final Widget sliver;

  @override
  State<SliverFadeOnChange> createState() => _SliverFadeOnChangeState();
}

class _SliverFadeOnChangeState extends State<SliverFadeOnChange>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: MTMotion.reveal,
    value: 1,
  );
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: MTMotion.entrance,
  );

  @override
  void didUpdateWidget(SliverFadeOnChange old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SliverFadeTransition(opacity: _opacity, sliver: widget.sliver);
}
