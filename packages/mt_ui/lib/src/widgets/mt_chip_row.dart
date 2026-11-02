import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

/// Chips on one line that scrolls sideways, for a list as long as the
/// library makes it (platforms, folders, tags): wrapped, nine platforms
/// and a few folders pushed a filter sheet past the screen. Put the chosen
/// chip first so it is never off the edge.
class MTChipRow extends StatelessWidget {
  const MTChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (i, chip) in children.indexed) ...[
          if (i > 0) const SizedBox(width: MTSpace.xs),
          chip,
        ],
      ],
    ),
  );
}
