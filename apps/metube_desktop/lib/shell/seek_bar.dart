import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'ember_slider.dart';
import 'keyboard.dart' show seekStep;

/// Elapsed time, the bar, and the length on one line, under the transport.
/// The bar follows the pointer while dragged and seeks once on release, so
/// a drag across a long clip is one seek rather than hundreds.
///
/// Over the picture ([onPicture]) the bar has the width to itself and the
/// times sit beneath as "0:40 / 3:10", beside [trailing]: a short's narrow
/// column has no room for both on one line.
class EmberSeekBar extends StatefulWidget {
  const EmberSeekBar({
    super.key,
    required this.player,
    required this.duration,
    this.onPicture = false,
    this.trailing,
  });

  final MTPlayer player;
  final Duration? duration;

  /// Light on the picture's own shade, which is dark in either theme.
  final bool onPicture;

  /// Set at the end of the times' line over the picture.
  final Widget? trailing;

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
    final picture = widget.onPicture;
    final time = Theme.of(context).textTheme.labelSmall?.tabular
        .copyWith(color: picture ? Colors.white70 : p.ink3);
    final length = maxMs > 0 ? mtFormatDuration(total) : '--:--';
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      initialData: widget.player.position,
      builder: (context, snap) {
        final at = snap.data ?? Duration.zero;
        final shownMs = (_dragMs ?? at.inMilliseconds.toDouble()).clamp(
          0.0,
          maxMs > 0 ? maxMs : 0.0,
        );
        final elapsed = mtFormatDuration(
          Duration(milliseconds: shownMs.round()),
        );
        final bar = EmberSlider(
          value: shownMs,
          max: maxMs,
          label: context.mtl.desktopSeekBar,
          // Read as the time it shows, not a bare percentage.
          describe: (v) => mtFormatDuration(Duration(milliseconds: v.round())),
          step: seekStep.inMilliseconds.toDouble(),
          inactive: picture ? Colors.white24 : null,
          onChanged: maxMs > 0 ? (v) => setState(() => _dragMs = v) : null,
          onChangeEnd: (v) {
            setState(() => _dragMs = null);
            widget.player.seek(Duration(milliseconds: v.round()));
          },
        );
        if (!picture) {
          return Row(
            children: [
              Text(elapsed, style: time),
              Expanded(child: bar),
              Text(length, style: time),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$elapsed / $length', style: time),
                    ),
                  ),
                ),
                if (widget.trailing case final trailing?)
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
