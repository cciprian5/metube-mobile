import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// The lab's pretend input, from the command line: see [labHoverFrom] and
/// [labKeysFrom]. Nothing outside a debug build.
void runLab(List<String> args) {
  runLabHover(labHoverFrom(args));
  runLabKeys(labKeysFrom(args));
}

/// A key the lab presses, and when.
typedef LabKey = (LogicalKeyboardKey, PhysicalKeyboardKey, Duration);

/// Keys to press, `--lab-keys=space@30;f11@31` (a key's name in
/// [LogicalKeyboardKey]'s debug names, lower case, and the seconds after
/// start): **debug builds only**, so what a key does (full screen, the
/// volume notice) can be checked in the real window without typing into
/// the user's foreground window. Empty outside a debug build.
List<LabKey> labKeysFrom(List<String> args) {
  if (!kDebugMode) return const [];
  const keys = {
    'space': (LogicalKeyboardKey.space, PhysicalKeyboardKey.space),
    'f11': (LogicalKeyboardKey.f11, PhysicalKeyboardKey.f11),
    'escape': (LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape),
    'up': (LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp),
    'down': (LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown),
  };
  for (final a in args) {
    if (!a.startsWith('--lab-keys=')) continue;
    return [
      for (final press in a.substring(11).split(';'))
        if (press.split('@') case [final name, final at])
          if ((keys[name], int.tryParse(at)) case (
            (final logical, final physical)?,
            final s?,
          ))
            (logical, physical, Duration(seconds: s)),
    ];
  }
  return const [];
}

/// Presses each of [keys] at its time, down then up, through the same
/// keyboard state the real keys go through.
void runLabKeys(List<LabKey> keys) {
  for (final (logical, physical, at) in keys) {
    Timer(at, () {
      final stamp = Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch,
      );
      HardwareKeyboard.instance
        ..handleKeyEvent(
          KeyDownEvent(
            physicalKey: physical,
            logicalKey: logical,
            timeStamp: stamp,
          ),
        )
        ..handleKeyEvent(
          KeyUpEvent(
            physicalKey: physical,
            logicalKey: logical,
            timeStamp: stamp,
          ),
        );
    });
  }
}

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
