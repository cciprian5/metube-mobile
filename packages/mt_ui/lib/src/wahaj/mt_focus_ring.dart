import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// The keyboard focus ring for the whole window: a 2px accent line around
/// whatever holds focus, **shown only while the keyboard is in use** (Tab,
/// arrows), never after a click, as in a browser.
///
/// **One layer at the top rather than a ring in every control**, so every
/// button, card, field and pill gets it without each having to know, and
/// the shared widgets stay as the phones have them. It sits outside any
/// zoom, in window coordinates, which is where focus reports its rect.
///
/// **Not [FocusManager.highlightMode]**: on a computer Flutter counts the
/// mouse as "traditional" input too, so that mode stays on after a click.
/// The layer watches for itself instead: a navigation key shows the ring,
/// any press of a pointer hides it.
///
/// The ring follows the focused control while it scrolls or moves, by
/// looking again after each frame the app draws anyway; it never asks for
/// a frame of its own, so an idle window stays idle.
class MTFocusRingLayer extends StatefulWidget {
  const MTFocusRingLayer({super.key, required this.child});

  final Widget child;

  /// The ring itself, for finding it in a test.
  static const ringKey = ValueKey('mt focus ring');

  @override
  State<MTFocusRingLayer> createState() => _MTFocusRingLayerState();
}

class _MTFocusRingLayerState extends State<MTFocusRingLayer> {
  Rect? _rect;
  bool _watching = false;

  /// The last thing the user did was move focus with the keyboard.
  bool _keyboard = false;

  FocusManager get _focus => FocusManager.instance;

  /// The keys that move focus around; typing in a field does not.
  static final _navigation = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    HardwareKeyboard.instance.addHandler(_onKey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && _navigation.contains(event.logicalKey)) {
      _keyboard = true;
      _changed();
    }
    return false;
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent && _keyboard) {
      _keyboard = false;
      _changed();
    }
  }

  /// The ring shows for keyboard use and a real control, not for a scope
  /// (the window itself holding focus).
  bool get _wanted {
    final node = _focus.primaryFocus;
    return _keyboard &&
        node != null &&
        node is! FocusScopeNode &&
        node.context != null;
  }

  void _changed() {
    _measure();
    if (_wanted && !_watching) {
      _watching = true;
      _watch();
    }
  }

  /// After every frame while the ring shows: the control may have moved.
  void _watch() {
    if (!mounted || !_wanted) {
      _watching = false;
      _measure();
      return;
    }
    _measure();
    SchedulerBinding.instance.addPostFrameCallback((_) => _watch());
  }

  void _measure() {
    if (!mounted) return;
    final rect = _wanted ? _focus.primaryFocus!.rect : null;
    if (rect != _rect) setState(() => _rect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (rect != null)
          Positioned.fromRect(
            key: MTFocusRingLayer.ringKey,
            rect: rect.inflate(MTDensity.desktop.focusRing),
            child: IgnorePointer(child: _Ring(size: rect.size)),
          ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final width = MTDensity.desktop.focusRing;
    // The control's own corners are not known from here: a card's corner,
    // or a pill's half-height when the control is smaller than that.
    final radius = size.shortestSide / 2 < MTCorners.desktop.card
        ? size.shortestSide / 2
        : MTCorners.desktop.card;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: p.accent, width: width),
        borderRadius: BorderRadius.circular(radius + width),
      ),
    );
  }
}
