import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// One ember of the glow, in units of the cover's side and relative to its
/// centre: where it is, how large, and how strong against the full one.
typedef MTEmber = ({Offset centre, double radius, double strength});

/// **The glow behind the cover moves while the sound plays** (requested
/// 2026-09-24, after Samsung Music's drifting background).
///
/// Samsung tints its background from the cover; that was declined,
/// because a clip's colours would repaint the app. So the idea is kept and
/// the source changed: the identity is called "glow", and this is light in
/// the app's **own accent** — ember in Super, petrol in Lite, read from the
/// palette like everything else.
///
/// **Two embers, circling opposite ways** (chosen 2026-09-24: one halo
/// breathing at the centre looked as if it stayed in one place).
/// The large one goes round the cover every nine seconds; the small one
/// the other way every thirteen, on a path that widens and narrows. The
/// periods share no factor, so where they meet and part is different every
/// time — random to the eye, smooth to it too. Both breathe on a five-second
/// cycle.
///
/// **It says something.** Moving means playing; paused, both embers draw
/// back to the centre within a second — the still halo of before — and
/// stay. And it stays still for anyone who turned animations off.
class MTBreathingGlow extends StatefulWidget {
  const MTBreathingGlow({
    super.key,
    required this.playing,
    required this.size,
    required this.child,
    this.clip,
  });

  final ValueListenable<bool> playing;

  /// What is playing. When it changes while the sound plays, the glow takes
  /// **one deeper breath** ([newClip]), so a new clip is felt before its
  /// title is read. Null never breathes so.
  final Object? clip;

  /// The cover's side; the embers are sized and moved from it.
  final double size;
  final Widget child;

  /// One breath.
  static const breath = Duration(seconds: 5);

  /// Settling to rest after a pause, and waking after a play.
  static const settle = Duration(milliseconds: 900);

  /// Waking after a play, on a computer: slower than settling, so the
  /// light wakes rather than switches on. A pause still settles quickly.
  static const wake = Duration(seconds: 2);

  /// The deeper breath when the clip changes.
  static const newClip = Duration(milliseconds: 1500);

  static const _largeTurn = 9.0;
  static const _smallTurn = 13.0;
  static const _smallSwell = 17.0;

  /// Every period divides it, so wrapping to zero lands each wave where it
  /// started.
  static const cycleSeconds = 5 * 9 * 13 * 17;

  /// **Where the embers are at [seconds], moving at [amplitude]** (0 at
  /// rest, 1 fully awake). Pure, so the motion itself is tested and not
  /// only whether a ticker runs.
  @visibleForTesting
  static (MTEmber, MTEmber) embersAt(
    double seconds,
    double amplitude, {
    double deeper = 0,
  }) {
    final swell =
        (1 - math.cos(2 * math.pi * seconds / breath.inSeconds)) /
            2 *
            amplitude +
        deeper;
    final large = 2 * math.pi * seconds / _largeTurn;
    // The other way round, starting across from the first.
    final small = math.pi - 2 * math.pi * seconds / _smallTurn;
    final reach = 0.30 + 0.08 * math.sin(2 * math.pi * seconds / _smallSwell);
    return (
      (
        // Wider than tall: the header above and the title below are
        // closer to the cover than the screen's sides are.
        centre:
            Offset(math.cos(large) * 0.36, math.sin(large) * 0.26) * amplitude,
        radius: 0.56 + 0.05 * swell,
        strength: 0.8 + 0.2 * swell,
      ),
      (
        centre:
            Offset(math.cos(small) * reach, math.sin(small) * reach * 0.8) *
            amplitude,
        radius: 0.42 + 0.04 * swell,
        strength: 0.55 + 0.2 * swell,
      ),
    );
  }

  @override
  State<MTBreathingGlow> createState() => _MTBreathingGlowState();
}

class _MTBreathingGlowState extends State<MTBreathingGlow>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: MTBreathingGlow.cycleSeconds),
  );

  late final AnimationController _amp =
      AnimationController(vsync: this, duration: MTBreathingGlow.settle)
        ..addStatusListener((status) {
          // Nothing moves at rest, so nothing needs a frame.
          if (status == AnimationStatus.dismissed) _clock.stop();
        });

  late final AnimationController _deeper = AnimationController(
    vsync: this,
    duration: MTBreathingGlow.newClip,
  );

  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.playing.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _amp
      ..duration = MTDesktopApp.isDesktop(context)
          ? MTBreathingGlow.wake
          : MTBreathingGlow.settle
      ..reverseDuration = MTBreathingGlow.settle;
    _sync();
  }

  @override
  void didUpdateWidget(MTBreathingGlow old) {
    super.didUpdateWidget(old);
    if (old.playing != widget.playing) {
      old.playing.removeListener(_sync);
      widget.playing.addListener(_sync);
      _sync();
    }
    if (widget.clip != null &&
        old.clip != widget.clip &&
        !_still &&
        widget.playing.value) {
      _deeper.forward(from: 0);
    }
  }

  void _sync() {
    if (_still) {
      _amp.value = 0;
      _clock.stop();
      return;
    }
    if (widget.playing.value) {
      if (!_clock.isAnimating) _clock.repeat();
      _amp.forward();
    } else {
      _amp.reverse();
    }
  }

  @override
  void dispose() {
    widget.playing.removeListener(_sync);
    _clock.dispose();
    _amp.dispose();
    _deeper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final desktop = MTDesktopApp.isDesktop(context);
    final light = desktop ? _emberLight() : null;
    // **On a computer, two shades of the ember**: the large slow one deep,
    // the small quick one bright, so the eye tells them apart and where
    // they cross reads warmer than either. Both from the palette, so the
    // petrol app gets two petrols.
    final colors = desktop ? [p.accentDeep, p.accent] : [p.accent, p.accent];
    // Night needs more of it to be seen on espresso than day needs on
    // cream, where a moving light too strong reads as a travelling stain;
    // on a large screen by day, more so.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final peak = dark ? 0.34 : (desktop ? 0.18 : 0.26);
    // Room for the farthest ember: its offset plus its radius, past the
    // cover's half.
    final reach = widget.size * 0.5;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -reach,
          top: -reach,
          right: -reach,
          bottom: -reach,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_clock, _amp, _deeper]),
                builder: (context, _) {
                  final (large, small) = MTBreathingGlow.embersAt(
                    _clock.value * MTBreathingGlow.cycleSeconds,
                    _amp.value,
                    // Rises and falls once over the deeper breath.
                    deeper: math.sin(math.pi * _deeper.value) * 0.6,
                  );
                  return CustomPaint(
                    painter: _EmberPainter(
                      embers: [large, small],
                      light: light,
                      side: widget.size,
                      colors: colors,
                      peak: peak,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// The side of [_emberLight], in pixels: smooth when stretched to an
/// ember's size, as it only fades.
const _lightSide = 256;

ui.Image? _light;

/// **One ember's light, drawn once**: white at full strength out to half
/// its radius, then fading, tinted to the accent as it is drawn.
///
/// On a computer the embers are drawn from it rather than from a gradient
/// worked out for every pixel of every frame. On the integrated graphics
/// of an ordinary laptop that gradient took about 18 ms a frame in a maximized
/// window, too long for 60 frames a second; the image takes about 2. Phones keep
/// the gradient, which is quick there.
ui.Image _emberLight() {
  if (_light case final ready?) return ready;
  final recorder = ui.PictureRecorder();
  final side = _lightSide.toDouble();
  final rect = Rect.fromLTWH(0, 0, side, side);
  Canvas(recorder)
      .drawRect(rect, Paint()..shader = _fade(Colors.white).createShader(rect));
  return _light = recorder.endRecording().toImageSync(_lightSide, _lightSide);
}

/// Full strength out to near the middle, then fading: the cover hides the
/// middle, and an ember that faded from its centre would show nothing as it
/// passed behind the edge.
RadialGradient _fade(Color color) => RadialGradient(
  colors: [color, color, color.withValues(alpha: 0)],
  stops: const [0, 0.5, 1],
);

class _EmberPainter extends CustomPainter {
  _EmberPainter({
    required this.embers,
    required this.light,
    required this.side,
    required this.colors,
    required this.peak,
  });

  final List<MTEmber> embers;

  /// The light drawn once, on a computer; null draws the gradient.
  final ui.Image? light;
  final double side;

  /// One per ember, in the same order.
  final List<Color> colors;
  final double peak;

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    for (final (i, ember) in embers.indexed) {
      final centre = middle + ember.centre * side;
      final radius = ember.radius * side;
      final alpha = peak * ember.strength;
      final rect = Rect.fromCircle(center: centre, radius: radius);
      final tint = colors[i].withValues(alpha: alpha.clamp(0, 1));
      if (light case final image?) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, _lightSide.toDouble(), _lightSide.toDouble()),
          rect,
          Paint()
            ..filterQuality = FilterQuality.low
            ..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
        );
      } else {
        canvas.drawCircle(
          centre,
          radius,
          Paint()..shader = _fade(tint).createShader(rect),
        );
      }
    }
  }

  // Driven by the builder above: every frame it runs is a changed frame.
  @override
  bool shouldRepaint(_EmberPainter old) => true;
}
