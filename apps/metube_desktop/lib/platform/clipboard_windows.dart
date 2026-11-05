import 'dart:async';

import 'package:flutter/services.dart';
import 'package:win32/win32.dart' show GetClipboardSequenceNumber;

import '../data/copied_links.dart';

/// Windows' clipboard, watched by its change count: Windows raises a
/// number each time anything is copied, so the clipboard itself is read
/// only after a new copy, never on every tick.
class WindowsClipboard implements ClipboardPort {
  Timer? _timer;
  int _seen = 0;

  @override
  void start(void Function(String text) onCopy) {
    stop();
    // What is there already was copied before the user asked.
    _seen = GetClipboardSequenceNumber();
    _timer = Timer.periodic(_every, (_) async {
      final now = GetClipboardSequenceNumber();
      if (now == _seen) return;
      _seen = now;
      try {
        final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        if (text != null && text.isNotEmpty) onCopy(text);
      } on PlatformException {
        // Another program holds the clipboard open; the next copy will do.
      }
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static const _every = Duration(seconds: 1);
}
