import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A help text kept to its first [lines], **with "More" to read the rest**.
/// Under a setting, three hundred characters in a block of small grey type
/// buried the setting itself; most readers need the first sentence, and the
/// rest is a click away. A text that fits shows no link.
class FoldedText extends StatefulWidget {
  const FoldedText(this.text, {super.key, this.style, this.lines = 2});

  final String text;
  final TextStyle? style;
  final int lines;

  @override
  State<FoldedText> createState() => _FoldedTextState();
}

class _FoldedTextState extends State<FoldedText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return LayoutBuilder(
      builder: (context, box) {
        final measure = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: DefaultTextStyle.of(context).style.merge(widget.style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: widget.lines,
        )..layout(maxWidth: box.maxWidth);
        final long = measure.didExceedMaxLines;
        measure.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _open || !long ? null : widget.lines,
              overflow: _open || !long ? null : TextOverflow.ellipsis,
            ),
            if (long)
              MTLinkButton(
                label: _open ? l.desktopLess : l.desktopMore,
                onPressed: () => setState(() => _open = !_open),
              ),
          ],
        );
      },
    );
  }
}
