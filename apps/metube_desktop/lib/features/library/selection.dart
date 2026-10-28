import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clips chosen in a list of clips, by canonical URL, and the one a
/// Shift-click counts from.
typedef LibrarySelection = ({Set<String> urls, String? anchor});

/// The selection: Ctrl adds or removes one, Shift takes the run from the
/// last one chosen, the round mark on a clip under the mouse adds or
/// removes it, and **while any is chosen a plain click adds or removes
/// too**. With none chosen a plain click opens the clip (the owner's
/// choice, 2026-10-28): choosing is something asked for, not what every
/// click does.
final librarySelectionProvider =
    NotifierProvider<LibrarySelectionNotifier, LibrarySelection>(
      LibrarySelectionNotifier.new,
    );

class LibrarySelectionNotifier extends Notifier<LibrarySelection> {
  @override
  LibrarySelection build() => (urls: const {}, anchor: null);

  /// A click on [url] in [order], the clips as shown, with the keys held.
  void click(String url, List<String> order) {
    final keys = HardwareKeyboard.instance;
    if (keys.isShiftPressed && state.anchor != null) {
      final from = order.indexOf(state.anchor!);
      final to = order.indexOf(url);
      if (from >= 0 && to >= 0) {
        final run = order.sublist(
          from < to ? from : to,
          (from < to ? to : from) + 1,
        );
        final keep = keys.isControlPressed ? state.urls : const <String>{};
        state = (urls: {...keep, ...run}, anchor: state.anchor);
        return;
      }
    }
    if (keys.isControlPressed || state.urls.isNotEmpty) return toggle(url);
    state = (urls: {url}, anchor: url);
  }

  /// Adds [url] to the choice, or takes it out.
  void toggle(String url) {
    final urls = {...state.urls};
    if (!urls.remove(url)) urls.add(url);
    state = (urls: urls, anchor: url);
  }

  void selectAll(List<String> order) =>
      state = (urls: order.toSet(), anchor: order.firstOrNull);

  void clear() => state = (urls: const {}, anchor: null);
}

/// Tells a mouse click from the same card's activation by Enter or a screen
/// reader, and a double click from two single ones. A click plays, unless
/// Ctrl or Shift is held or a choice is being made; the second click of a
/// double click is let go, so the clip does not start twice. Enter and a
/// screen reader always play.
class ClickClock {
  ClickClock._();

  static DateTime _down = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _lastUrl;

  /// The time the clicks are judged by. A widget test runs on simulated
  /// time and sets its own, so a slow machine does not split its double
  /// click in two.
  static DateTime Function() now = DateTime.now;

  /// A mouse button went down on a card.
  static void pointerDown() => _down = now();

  /// What an activation of [url] means, judged now; [choosing] says some
  /// clip is already chosen.
  static ClickMeaning activate(String url, {bool choosing = false}) {
    final now = ClickClock.now();
    // An activation with no button just down came from the keyboard or a
    // screen reader.
    if (now.difference(_down) > const Duration(milliseconds: 600)) {
      return ClickMeaning.play;
    }
    final keys = HardwareKeyboard.instance;
    if (choosing || keys.isControlPressed || keys.isShiftPressed) {
      return ClickMeaning.choose;
    }
    final twice =
        _lastUrl == url && now.difference(_lastClick) <= kDoubleTapTimeout;
    _lastUrl = twice ? null : url;
    _lastClick = now;
    return twice ? ClickMeaning.none : ClickMeaning.play;
  }
}

enum ClickMeaning { choose, play, none }
