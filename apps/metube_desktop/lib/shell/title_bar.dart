import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../identity.dart';
import 'caption_button.dart';
import 'ember_mark.dart';
import 'focus_regions.dart';
import 'shell_metrics.dart';
import 'window_controls.dart';

/// The drawn title bar, and the window's one bar: Windows' own white or
/// black strip would cut straight across the cream paper, and a second bar
/// under it for back, search and downloads cost a row of the content.
///
/// Above the sidebar sit its toggle and the app's name, above the content
/// [tools], and the three caption buttons where the reading direction
/// puts them, as Windows does for its own windows. **Every bit of bare bar
/// moves the window** and a double click on it maximizes: the ground lies
/// under the controls, so a click on a control never waits to learn
/// whether it was the first of two.
class EmberTitleBar extends StatelessWidget {
  const EmberTitleBar({
    super.key,
    required this.controls,
    this.startWidth,
    this.sidebarToggle,
    this.tools,
  });

  final WindowControls controls;

  /// The start column's width from which the mark and the name fit beside
  /// the sidebar's toggle.
  static const double _nameRoom =
      EmberShellSize.sidebarNarrow + MTSpace.xxl * 2;

  /// The width of the sidebar below, so the toggle and the name stand over
  /// it and [tools] start where the content does. null sizes them to fit.
  final double? startWidth;

  /// Narrows or widens the sidebar; null when the window has no room for
  /// the wide one.
  final Widget? sidebarToggle;

  /// Back and forward, the search, the downloads and the panel's button.
  final Widget? tools;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final named =
        (startWidth ?? double.infinity) > EmberShellSize.sidebarNarrow;
    return ColoredBox(
      color: p.bg,
      child: SizedBox(
        height: EmberShellSize.titleBar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => controls.startDragging(),
              onDoubleTap: controls.toggleMaximize,
            ),
            Row(
              children: [
                // Narrowed or widened with the sidebar below, at its pace:
                // a column that snapped while the sidebar moved under it
                // read as two things out of step.
                AnimatedContainer(
                  duration: mtMotionDuration(context, MTMotion.medium),
                  curve: MTMotion.ease,
                  width: startWidth,
                  // The name comes in once the moving column has room for
                  // it, not on the first frame of a widening, where it
                  // spilled past the narrow width.
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final room =
                          named && box.maxWidth >= EmberTitleBar._nameRoom;
                      return Row(
                        mainAxisSize: startWidth == null
                            ? MainAxisSize.min
                            : MainAxisSize.max,
                        mainAxisAlignment: room || sidebarToggle == null
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          if (room || sidebarToggle == null)
                            const SizedBox(width: MTSpace.md),
                          ?sidebarToggle,
                          if (room || sidebarToggle == null)
                            Flexible(child: _Name(named: room)),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(child: tools ?? const SizedBox.shrink()),
                inRegion(
                  EmberRegion.titleBar,
                  Row(
                    children: [
                      CaptionButton(
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
                      CaptionButton(
                        icon: MTIcons.winClose,
                        label: l.desktopWindowClose,
                        onTap: controls.close,
                        danger: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The mark and, given room, the app's name. It takes no pointer, so a
/// drag that starts on it still moves the window.
class _Name extends StatelessWidget {
  const _Name({required this.named});

  final bool named;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return IgnorePointer(
      child: inRegion(
        EmberRegion.titleBar,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: MTSpace.xs),
            const EmberMark(size: MTSpace.xl),
            if (named) ...[
              const SizedBox(width: MTSpace.xs),
              Flexible(
                child: Text(
                  EmberIdentity.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MTType.display,
                    package: MTType.package,
                    fontWeight: FontWeight.w500,
                    fontSize: MTTypeScale.desktop.secondary,
                    color: p.ink2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
        builder: (context, hovered, _) => CaptionButton(
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

  /// **Gone from the screen, the button gives its place back.** The runner
  /// keeps the last place it was told and answers Windows there as the
  /// maximize button. The small card and full screen draw no title bar, so
  /// that corner of the card, or of the picture, went on acting as one: in
  /// Arabic it lay over the card's next button, which maximized the card,
  /// and once the card could not be, did nothing.
  @override
  void dispose() {
    widget.onPlaced(Rect.zero);
    super.dispose();
  }

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
