import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The way into choosing**: a round mark at the clip's starting corner,
/// shown under the mouse, on every clip once one is chosen, and filled
/// with a check on a chosen one. A click on it chooses without opening;
/// Ctrl and Shift clicks still work as in Windows' own lists.
class ChooseMark extends StatefulWidget {
  const ChooseMark({
    super.key,
    required this.chosen,
    required this.choosing,
    required this.onToggle,
    required this.child,
  });

  final bool chosen;
  final bool choosing;

  /// Null leaves the mark out.
  final VoidCallback? onToggle;
  final Widget child;

  /// The mark's size.
  static const double size = MTSpace.xl + MTSpace.xxs;

  /// The mark itself, for tests.
  static const markKey = ValueKey('choose mark');

  @override
  State<ChooseMark> createState() => _ChooseMarkState();
}

class _ChooseMarkState extends State<ChooseMark> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final toggle = widget.onToggle;
    if (toggle == null) return widget.child;
    final shown = _hovered || widget.choosing || widget.chosen;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          widget.child,
          PositionedDirectional(
            top: MTSpace.xs,
            start: MTSpace.xs,
            child: IgnorePointer(
              ignoring: !shown,
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: mtMotionDuration(context, MTMotion.fast),
                child: _Mark(
                  key: ChooseMark.markKey,
                  chosen: widget.chosen,
                  onTap: toggle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({super.key, required this.chosen, required this.onTap});

  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final label = context.mtl.desktopChooseClip;
    return MTShortcutTooltip(
      message: label,
      shortcut: 'Ctrl',
      child: Semantics(
        checked: chosen,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            // Dark under white in day and night alike, like the cover's
            // buttons: it sits over a picture of any colour.
            child: Container(
              width: ChooseMark.size,
              height: ChooseMark.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chosen
                    ? p.accent
                    : MTPalette.fullscreenScrim.withValues(alpha: 0.45),
                border: Border.all(color: Colors.white, width: 1.6),
              ),
              child: chosen
                  ? MTIcon(MTIcons.check, size: MTSpace.md, color: p.onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
