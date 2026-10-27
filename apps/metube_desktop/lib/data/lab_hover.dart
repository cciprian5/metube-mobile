import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Points to rest a pointer on, `--lab-hover=720,610;480,600` in logical
/// pixels: **debug builds only**, so what a hover shows (a tooltip, a
/// card's lift) can be checked in the real window without moving the
/// user's own mouse. Empty outside a debug build.
List<Offset> labHoverFrom(List<String> args) {
  if (!kDebugMode) return const [];
  for (final a in args) {
    if (!a.startsWith('--lab-hover=')) continue;
    return [
      for (final point in a.substring(12).split(';'))
        if (point.split(',') case [final x, final y])
          if ((double.tryParse(x), double.tryParse(y)) case (
            final dx?,
            final dy?,
          ))
            Offset(dx, dy),
    ];
  }
  return const [];
}

/// Rests a pretend mouse on each of [points] in turn, a few seconds
/// apart, starting once the window has settled. It is a device of its
/// own, so the real pointer's place is left alone.
void runLabHover(List<Offset> points) {
  if (points.isEmpty) return;
  const device = 9001;
  final binding = GestureBinding.instance;
  var at = const Duration(seconds: 6);
  for (final (i, point) in points.indexed) {
    Timer(at, () {
      if (i == 0) {
        binding.handlePointerEvent(
          PointerAddedEvent(
            kind: PointerDeviceKind.mouse,
            device: device,
            position: point,
          ),
        );
      }
      binding.handlePointerEvent(
        PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          device: device,
          position: point,
        ),
      );
    });
    at += const Duration(milliseconds: 2500);
  }
}
