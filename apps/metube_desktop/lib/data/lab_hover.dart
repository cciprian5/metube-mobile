import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// The lab's pretend input, from the command line: see [labHoverFrom],
/// [labKeysFrom], [labTapsFrom] and [labScrollsFrom]. Nothing outside a debug build.
void runLab(List<String> args) {
  runLabHover(labHoverFrom(args));
  runLabKeys(labKeysFrom(args));
  runLabTaps(labTapsFrom(args));
  runLabTaps(
    labTapsFrom(args, flag: '--lab-rtap='),
    buttons: kSecondaryMouseButton,
  );
  runLabScrolls(labScrollsFrom(args));
}

/// A point the lab clicks, and when.
typedef LabTap = (Offset, Duration);

/// Clicks, `--lab-tap=640,520@20` in logical pixels and the seconds after
/// start: **debug builds only**, so a button with no key (theater) can be
/// pressed in the real window without the user's own mouse. Empty outside
/// a debug build.
///
/// `--lab-rtap=` is the same with the right button, for a context menu.
List<LabTap> labTapsFrom(List<String> args, {String flag = '--lab-tap='}) {
  if (!kDebugMode) return const [];
  for (final a in args) {
    if (!a.startsWith(flag)) continue;
    return [
      for (final tap in a.substring(flag.length).split(';'))
        if (tap.split('@') case [final point, final at])
          if (point.split(',') case [final x, final y])
            if ((double.tryParse(x), double.tryParse(y), int.tryParse(at))
                case (final dx?, final dy?, final s?))
              (Offset(dx, dy), Duration(seconds: s)),
    ];
  }
  return const [];
}

/// Clicks each of [taps] at its time with a pretend mouse of its own, so
/// the real pointer stays where the user left it.
void runLabTaps(List<LabTap> taps, {int buttons = kPrimaryMouseButton}) {
  final device = buttons == kPrimaryMouseButton ? 9002 : 9003;
  final binding = GestureBinding.instance;
  for (final (i, (point, at)) in taps.indexed) {
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
      binding
        ..handlePointerEvent(
          PointerHoverEvent(
            kind: PointerDeviceKind.mouse,
            device: device,
            position: point,
          ),
        )
        ..handlePointerEvent(
          PointerDownEvent(
            kind: PointerDeviceKind.mouse,
            device: device,
            position: point,
            buttons: buttons,
          ),
        )
        ..handlePointerEvent(
          PointerUpEvent(
            kind: PointerDeviceKind.mouse,
            device: device,
            position: point,
          ),
        );
    });
  }
}

/// A key the lab presses, and when, with the keys [held] down around it.
typedef LabKey = (
  LogicalKeyboardKey,
  PhysicalKeyboardKey,
  Duration, {
  List<(LogicalKeyboardKey, PhysicalKeyboardKey)> held,
});

/// Keys to press, `--lab-keys=space@30;f11@31` (a key's name in
/// [LogicalKeyboardKey]'s debug names, lower case, and the seconds after
/// start), `ctrl+shift+c@20` with keys held: **debug builds only**, so what a key does (full screen, the
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
    'c': (LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC),
  };
  for (final a in args) {
    if (!a.startsWith('--lab-keys=')) continue;
    return [
      for (final press in a.substring(11).split(';'))
        if (press.split('@') case [final name, final at])
          if ((keys[name.split('+').last], int.tryParse(at)) case (
            (final logical, final physical)?,
            final s?,
          ))
            if (_heldIn(name) case final held?)
              (logical, physical, Duration(seconds: s), held: held),
    ];
  }
  return const [];
}

/// Presses each of [keys] at its time, down then up, through the same
/// keyboard state the real keys go through.
void runLabKeys(List<LabKey> keys) {
  for (final (logical, physical, at, :held) in keys) {
    Timer(at, () {
      final stamp = Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch,
      );
      final keyboard = HardwareKeyboard.instance;
      void send((LogicalKeyboardKey, PhysicalKeyboardKey) key, bool down) =>
          keyboard.handleKeyEvent(
            down
                ? KeyDownEvent(
                    physicalKey: key.$2,
                    logicalKey: key.$1,
                    timeStamp: stamp,
                  )
                : KeyUpEvent(
                    physicalKey: key.$2,
                    logicalKey: key.$1,
                    timeStamp: stamp,
                  ),
          );
      for (final key in held) {
        send(key, true);
      }
      send((logical, physical), true);
      send((logical, physical), false);
      for (final key in held.reversed) {
        send(key, false);
      }
    });
  }
}

/// The keys held under a lab press named `ctrl+shift+c`; null when one of
/// them is not known.
List<(LogicalKeyboardKey, PhysicalKeyboardKey)>? _heldIn(String name) {
  const known = {
    'ctrl': (LogicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlLeft),
    'shift': (LogicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftLeft),
  };
  final parts = name.split('+');
  final held = [for (final p in parts.take(parts.length - 1)) known[p]];
  return held.contains(null) ? null : held.nonNulls.toList();
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

/// A wheel turn the lab makes: where, how far down, and when.
typedef LabScroll = (Offset, double, Duration);

/// Wheel turns, `--lab-scroll=700,500,1200@10` in logical pixels and the
/// seconds after start: **debug builds only**, so what scrolling shows (a
/// heading held at the top) can be checked in the real window without the
/// user's own mouse. Empty outside a debug build.
List<LabScroll> labScrollsFrom(List<String> args) {
  if (!kDebugMode) return const [];
  for (final a in args) {
    if (!a.startsWith('--lab-scroll=')) continue;
    return [
      for (final turn in a.substring(13).split(';'))
        if (turn.split('@') case [final where, final at])
          if (where.split(',') case [final x, final y, final dy])
            if ((
                  double.tryParse(x),
                  double.tryParse(y),
                  double.tryParse(dy),
                  int.tryParse(at),
                )
                case (final px?, final py?, final down?, final s?))
              (Offset(px, py), down, Duration(seconds: s)),
    ];
  }
  return const [];
}

/// Turns the wheel of a pretend mouse of its own for each of [turns].
void runLabScrolls(List<LabScroll> turns) {
  const device = 9003;
  final binding = GestureBinding.instance;
  for (final (i, (point, down, at)) in turns.indexed) {
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
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          device: device,
          position: point,
          scrollDelta: Offset(0, down),
        ),
      );
    });
  }
}
