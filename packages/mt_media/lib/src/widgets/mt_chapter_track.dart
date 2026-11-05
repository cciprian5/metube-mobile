import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A slider track cut where each chapter begins: the same fill, buffer
/// and rest as a whole track, drawn piece by piece with a gap between.
class MTChapterTrackShape extends RoundedRectSliderTrackShape {
  const MTChapterTrackShape(this.marks);

  /// Where the cuts fall, as fractions of the track, each between 0 and 1.
  final List<double> marks;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    if (marks.isEmpty) {
      return super.paint(
        context,
        offset,
        parentBox: parentBox,
        sliderTheme: sliderTheme,
        enableAnimation: enableAnimation,
        textDirection: textDirection,
        thumbCenter: thumbCenter,
        secondaryOffset: secondaryOffset,
        isDiscrete: isDiscrete,
        isEnabled: isEnabled,
        additionalActiveTrackHeight: additionalActiveTrackHeight,
      );
    }
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final radius = Radius.circular(track.height / 2);
    final edges = [
      track.left,
      for (final m in marks) track.left + track.width * m,
      track.right,
    ];
    void fill(RRect piece, double upTo, Color? color) {
      if (color == null || upTo <= piece.left) return;
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(piece.left, piece.top, upTo, piece.bottom))
        ..drawRRect(piece, Paint()..color = color)
        ..restore();
    }

    for (var i = 0; i + 1 < edges.length; i++) {
      final left = edges[i] + (i == 0 ? 0 : _gap / 2);
      final right = edges[i + 1] - (i + 2 == edges.length ? 0 : _gap / 2);
      if (right <= left) continue;
      final piece = RRect.fromLTRBR(
        left,
        track.top,
        right,
        track.bottom,
        radius,
      );
      fill(piece, right, sliderTheme.inactiveTrackColor);
      fill(
        piece,
        secondaryOffset?.dx ?? left,
        sliderTheme.secondaryActiveTrackColor,
      );
      fill(piece, thumbCenter.dx, sliderTheme.activeTrackColor);
    }
  }

  static const _gap = MTSpace.xxs;
}
