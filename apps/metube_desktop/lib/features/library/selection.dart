import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clips chosen in a list of clips, by canonical URL, and the one a
/// Shift-click counts from.
typedef LibrarySelection = ({Set<String> urls, String? anchor});

/// The selection, as in Windows' own lists: a click chooses one, Ctrl adds
/// or removes one, Shift takes the run from the last one chosen.
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
    if (keys.isControlPressed) {
      final urls = {...state.urls};
      if (!urls.remove(url)) urls.add(url);
      state = (urls: urls, anchor: url);
      return;
    }
    state = (urls: {url}, anchor: url);
  }

  void selectAll(List<String> order) =>
      state = (urls: order.toSet(), anchor: order.firstOrNull);

  void clear() => state = (urls: const {}, anchor: null);
}

/// Tells a mouse click from the same card's activation by Enter or a screen
/// reader, and a double click from two single ones. A click chooses; a
/// double click, Enter or a screen reader's activation plays, so the
/// keyboard and assistive technology keep playing with one action.
class ClickClock {
  ClickClock._();

  static DateTime _down = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _lastClick = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _lastUrl;

  /// A mouse button went down on a card.
  static void pointerDown() => _down = DateTime.now();

  /// What an activation of [url] means, judged now.
  static ClickMeaning activate(String url) {
    final now = DateTime.now();
    // An activation with no button just down came from the keyboard or a
    // screen reader.
    if (now.difference(_down) > const Duration(milliseconds: 600)) {
      return ClickMeaning.play;
    }
    final twice =
        _lastUrl == url && now.difference(_lastClick) <= kDoubleTapTimeout;
    _lastUrl = twice ? null : url;
    _lastClick = now;
    return twice ? ClickMeaning.play : ClickMeaning.choose;
  }
}

enum ClickMeaning { choose, play }
