import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The app's slider: a thin track, the part played in the accent, and a
/// round thumb. Low to high from left to right, in either language, as
/// time and loudness run.
///
/// **Drawn here rather than Material's `Slider`**, which keeps an overlay
/// (its value bubble) always shown. On Windows that overlay's
/// accessibility node reached the engine with no parent; the engine's
/// accessibility bridge then took it for the tree's root, every later
/// update failed, and one of them crashed the app (measured on Flutter
/// 3.47, whenever a screen reader or any UI Automation client, Windows'
/// own text input among them, is attached). This one has no overlay, and
/// tells a screen reader the same: a slider, its value, and what one step
/// up or down would make it.
class EmberSlider extends StatefulWidget {
  const EmberSlider({
    super.key,
    required this.value,
    required this.max,
    required this.label,
    required this.describe,
    required this.step,
    required this.onChanged,
    this.onChangeEnd,
    this.inactive,
  });

  final double value;

  /// The top of the range; zero or less leaves the slider unmovable.
  final double max;

  final String label;

  /// The value as a screen reader says it: "1:05", "Volume 40%".
  final String Function(double value) describe;

  /// How far a screen reader's increase or decrease moves it.
  final double step;

  /// Every move of a drag; null leaves the slider unmovable.
  final ValueChanged<double>? onChanged;

  /// Where a drag or a click ended, once.
  final ValueChanged<double>? onChangeEnd;

  /// The track beyond the thumb; the theme's hairline when null.
  final Color? inactive;

  /// The height it takes, the thumb's halo included.
  static const double height = MTSpace.md * 2;

  @override
  State<EmberSlider> createState() => _EmberSliderState();
}

class _EmberSliderState extends State<EmberSlider> {
  bool _hover = false;
  bool _dragging = false;
  double? _last;

  bool get _enabled => widget.onChanged != null && widget.max > 0;

  double _clamped(double v) => v.clamp(0.0, math.max(widget.max, 0.0));

  double _at(double dx, double width) {
    const inset = MTSpace.md;
    final span = math.max(width - 2 * inset, 1.0);
    return ((dx - inset) / span).clamp(0.0, 1.0) * widget.max;
  }

  void _move(double v) {
    _last = v;
    widget.onChanged?.call(v);
  }

  void _end() {
    final v = _last;
    setState(() => _dragging = false);
    if (v != null) widget.onChangeEnd?.call(v);
    _last = null;
  }

  void _stepTo(double v) {
    _move(_clamped(v));
    _end();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final value = _clamped(widget.value);
    final enabled = _enabled;
    return Semantics(
      slider: true,
      enabled: enabled,
      label: widget.label,
      value: widget.describe(value),
      increasedValue: widget.describe(_clamped(value + widget.step)),
      decreasedValue: widget.describe(_clamped(value - widget.step)),
      onIncrease: enabled ? () => _stepTo(value + widget.step) : null,
      onDecrease: enabled ? () => _stepTo(value - widget.step) : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onTapDown: enabled
                ? (d) => _move(_at(d.localPosition.dx, box.maxWidth))
                : null,
            onTapUp: enabled ? (_) => _end() : null,
            onHorizontalDragStart: enabled
                ? (d) {
                    setState(() => _dragging = true);
                    _move(_at(d.localPosition.dx, box.maxWidth));
                  }
                : null,
            onHorizontalDragUpdate: enabled
                ? (d) => _move(_at(d.localPosition.dx, box.maxWidth))
                : null,
            onHorizontalDragEnd: enabled ? (_) => _end() : null,
            child: CustomPaint(
              size: Size(box.maxWidth, EmberSlider.height),
              painter: _SliderPainter(
                fraction: widget.max > 0 ? value / widget.max : 0,
                active: enabled ? p.accent : p.ink3,
                inactive: widget.inactive ?? p.line2,
                halo: enabled && (_hover || _dragging) ? p.accentSoft : null,
                track: MTSpace.xxs / 2,
                thumb: MTSpace.xs,
                inset: MTSpace.md,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({
    required this.fraction,
    required this.active,
    required this.inactive,
    required this.halo,
    required this.track,
    required this.thumb,
    required this.inset,
  });

  final double fraction;
  final Color active;
  final Color inactive;
  final Color? halo;
  final double track;
  final double thumb;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = inset;
    final end = math.max(size.width - inset, start);
    final x = start + (end - start) * fraction;
    final line = Paint()
      ..strokeWidth = track
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(x, y), Offset(end, y), line..color = inactive)
      ..drawLine(Offset(start, y), Offset(x, y), line..color = active);
    if (halo case final color?) {
      canvas.drawCircle(Offset(x, y), inset, Paint()..color = color);
    }
    canvas.drawCircle(Offset(x, y), thumb, Paint()..color = active);
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.fraction != fraction ||
      old.active != active ||
      old.inactive != inactive ||
      old.halo != halo;
}
