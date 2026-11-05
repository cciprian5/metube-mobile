import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

/// Whether the arrow may move at all. Always so in the app; tests of the
/// rest of the window turn it off, since a loop that runs while anything
/// downloads never lets the window settle.
final downloadMotionProvider = Provider<bool>((ref) => true);

/// **The download arrow, moving while something downloads**, as on the
/// phone: a count alone said how many, not that anything was happening.
///
/// The arrow drops into the tray and fades, then comes back from above, on
/// the phone's own calm loop ([mtDownloadDrop]); the tray stays put. At
/// zero, or when Windows asks for no animations, it stands still, so the
/// motion itself is the news.
class DownloadGlyph extends StatefulWidget {
  const DownloadGlyph({
    super.key,
    required this.active,
    required this.color,
    this.motion = true,
  });

  /// How many downloads are running.
  final int active;
  final Color color;

  /// false keeps it still whatever runs (see [downloadMotionProvider]).
  final bool motion;

  @override
  State<DownloadGlyph> createState() => _DownloadGlyphState();
}

class _DownloadGlyphState extends State<DownloadGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: MTDownloadsIcon.period,
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(DownloadGlyph old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final moving = widget.active > 0 && widget.motion && !_still;
    if (moving && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!moving && _loop.isAnimating) {
      // Stops upright, not half faded.
      _loop
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = MTIcon(
      MTIcons.download,
      size: MTDensity.desktop.icon,
      color: widget.color,
    );
    return Stack(
      children: [
        ClipRect(clipper: const _Band(top: false), child: glyph),
        ClipRect(
          clipper: const _Band(top: true),
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, child) {
              final (offset, opacity) = mtDownloadDrop(_loop.value);
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, offset * MTDownloadsIcon.drop),
                  child: child,
                ),
              );
            },
            child: glyph,
          ),
        ),
      ],
    );
  }
}

/// Half of the glyph: the arrow above the cut, or the tray below. The arrow
/// ends at 15.6 and the tray starts at 18 on the glyph's 24-point grid, so
/// a cut at 17 keeps each whole and the arrow vanishes into the tray.
class _Band extends CustomClipper<Rect> {
  const _Band({required this.top});

  final bool top;

  static const double _cut = 17 / 24;

  @override
  Rect getClip(Size size) {
    final cut = size.height * _cut;
    return top
        ? Rect.fromLTRB(0, 0, size.width, cut)
        : Rect.fromLTRB(0, cut, size.width, size.height);
  }

  @override
  bool shouldReclip(_Band old) => old.top != top;
}
