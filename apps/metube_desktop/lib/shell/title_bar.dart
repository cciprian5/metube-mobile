import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../identity.dart';
import 'shell_metrics.dart';
import 'window_controls.dart';

/// The drawn title bar: Windows' own white or black strip would cut
/// straight across the cream paper. The whole bar drags the window and a
/// double click maximizes it; the three caption buttons sit where the
/// reading direction puts them, as Windows does for its own windows.
class EmberTitleBar extends StatelessWidget {
  const EmberTitleBar({super.key, required this.controls});

  final WindowControls controls;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    return ColoredBox(
      color: p.bg,
      child: SizedBox(
        height: EmberShellSize.titleBar,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => controls.startDragging(),
                onDoubleTap: controls.toggleMaximize,
                child: Row(
                  children: [
                    const SizedBox(width: MTSpace.md),
                    _Dot(color: p.accent),
                    const SizedBox(width: MTSpace.xs),
                    Text(
                      EmberIdentity.displayName,
                      style: TextStyle(
                        fontFamily: MTType.display,
                        package: MTType.package,
                        fontWeight: FontWeight.w500,
                        fontSize: MTTypeScale.desktop.secondary,
                        color: p.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _CaptionButton(
              icon: MTIcons.winMin,
              label: l.desktopWindowMinimize,
              onTap: controls.minimize,
            ),
            ValueListenableBuilder<bool>(
              valueListenable: controls.maximized,
              builder: (context, maximized, _) => _MaximizeButton(
                controls: controls,
                label: maximized
                    ? l.desktopWindowRestore
                    : l.desktopWindowMaximize,
              ),
            ),
            _CaptionButton(
              icon: MTIcons.winClose,
              label: l.desktopWindowClose,
              onTap: controls.close,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: MTSpace.xs,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// The maximize button tells Windows where it is after every layout, so
/// hovering it opens Snap Layouts. Windows then owns its hover and clicks,
/// and the hover comes back through [WindowControls.maximizeHovered].
class _MaximizeButton extends StatelessWidget {
  const _MaximizeButton({required this.controls, required this.label});

  final WindowControls controls;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _ReportPlace(
      onPlaced: controls.reportMaximizeButton,
      child: ValueListenableBuilder<bool>(
        valueListenable: controls.maximizeHovered,
        builder: (context, hovered, _) => _CaptionButton(
          icon: MTIcons.winMax,
          label: label,
          onTap: controls.toggleMaximize,
          forceHover: hovered,
        ),
      ),
    );
  }
}

/// Reports its child's rectangle in physical pixels after each frame.
class _ReportPlace extends StatefulWidget {
  const _ReportPlace({required this.onPlaced, required this.child});

  final ValueChanged<Rect> onPlaced;
  final Widget child;

  @override
  State<_ReportPlace> createState() => _ReportPlaceState();
}

class _ReportPlaceState extends State<_ReportPlace> {
  Rect? _sent;

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // The view's own ratio, not MediaQuery's: the interface size setting
    // scales MediaQuery, while Windows counts real pixels.
    final ratio = View.of(context).devicePixelRatio;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero) * ratio,
      box.localToGlobal(box.size.bottomRight(Offset.zero)) * ratio,
    );
    if (rect == _sent) return;
    _sent = rect;
    widget.onPlaced(rect);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.forceHover = false,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback onTap;

  /// The close button turns red under the pointer, as Windows' does.
  final bool danger;
  final bool forceHover;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final lit = _hover || widget.forceHover;
    final fill = !lit ? null : (widget.danger ? p.err : p.cardAlt);
    final ink = lit && widget.danger ? p.bg : p.ink2;
    return Semantics(
      button: true,
      label: widget.label,
      child: MTShortcutTooltip(
        message: widget.label,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: MTMotion.fast,
              width: EmberShellSize.captionButton,
              height: EmberShellSize.titleBar,
              color: fill ?? p.bg,
              alignment: Alignment.center,
              child: MTIcon(widget.icon, size: MTSpace.lg, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
