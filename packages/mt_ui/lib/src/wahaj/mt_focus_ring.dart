import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
/// The ring follows the focused control while it scrolls or moves; it
/// listens only while it is shown.
class MTFocusRingLayer extends StatefulWidget {
  const MTFocusRingLayer({super.key, required this.child});

  final Widget child;

  @override
  State<MTFocusRingLayer> createState() => _MTFocusRingLayerState();
}

class _MTFocusRingLayerState extends State<MTFocusRingLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _follow = createTicker((_) => _measure());
  Rect? _rect;

  FocusManager get _focus => FocusManager.instance;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    _focus.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _focus.removeHighlightModeListener(_modeChanged);
    _follow.dispose();
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode _) => _changed();

  /// The ring shows for keyboard use and a real control, not for a scope
  /// (the window itself holding focus).
  bool get _wanted {
    final node = _focus.primaryFocus;
    return _focus.highlightMode == FocusHighlightMode.traditional &&
        node != null &&
        node is! FocusScopeNode &&
        node.context != null;
  }

  void _changed() {
    if (_wanted) {
      if (!_follow.isActive) unawaited(_follow.start());
      _measure();
    } else {
      if (_follow.isActive) _follow.stop();
      if (_rect != null && mounted) setState(() => _rect = null);
    }
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
