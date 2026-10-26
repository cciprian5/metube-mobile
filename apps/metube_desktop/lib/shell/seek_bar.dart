import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

/// Elapsed time, the bar, and the length on one line, under the transport.
/// The bar follows the pointer while dragged and seeks once on release, so
/// a drag across a long clip is one seek rather than hundreds.
class EmberSeekBar extends StatefulWidget {
  const EmberSeekBar({super.key, required this.player, required this.duration});

  final MTPlayer player;
  final Duration? duration;

  @override
  State<EmberSeekBar> createState() => _EmberSeekBarState();
}

class _EmberSeekBarState extends State<EmberSeekBar> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final total = widget.duration ?? Duration.zero;
    final maxMs = total.inMilliseconds.toDouble();
    final time = Theme.of(context).textTheme.labelSmall?.tabular
        .copyWith(color: p.ink3);
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      initialData: widget.player.position,
      builder: (context, snap) {
        final at = snap.data ?? Duration.zero;
        final shownMs = (_dragMs ?? at.inMilliseconds.toDouble()).clamp(
          0.0,
          maxMs > 0 ? maxMs : 0.0,
        );
        return Row(
          children: [
            Text(
              mtFormatDuration(Duration(milliseconds: shownMs.round())),
              style: time,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: MTSpace.xxs / 2,
                  activeTrackColor: p.accent,
                  inactiveTrackColor: p.line2,
                  thumbColor: p.accent,
                  overlayColor: p.accentSoft,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: MTSpace.xs,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: MTSpace.md,
                  ),
                ),
                child: Slider(
                  label: context.mtl.desktopSeekBar,
                  // Read as the time it shows, not a bare percentage.
                  semanticFormatterCallback: (v) =>
                      mtFormatDuration(Duration(milliseconds: v.round())),
                  value: shownMs,
                  max: maxMs > 0 ? maxMs : 1,
                  onChanged: maxMs > 0
                      ? (v) => setState(() => _dragMs = v)
                      : null,
                  onChangeEnd: maxMs > 0
                      ? (v) {
                          setState(() => _dragMs = null);
                          widget.player.seek(Duration(milliseconds: v.round()));
                        }
                      : null,
                ),
              ),
            ),
            Text(maxMs > 0 ? mtFormatDuration(total) : '--:--', style: time),
          ],
        );
      },
    );
  }
}
