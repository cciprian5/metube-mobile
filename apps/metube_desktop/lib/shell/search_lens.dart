import 'package:flutter/widgets.dart';
import 'package:mt_ui/mt_ui.dart';

/// The magnifier at the start of a search field, at the size the window's
/// search box draws it. Left to fill the field's icon slot, it grew to
/// three times that and read as a spinner.
/// Centred, since the field hands its icon slot a tight box.
Widget searchLens(MTPalette p) => Center(
  widthFactor: 1,
  heightFactor: 1,
  child: MTIcon(MTIcons.search, size: MTSpace.lg, color: p.ink3),
);
