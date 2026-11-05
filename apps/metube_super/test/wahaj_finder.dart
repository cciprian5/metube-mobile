import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// Finds a Wahaj icon on screen, as `find.byIcon` finds a Material one.
Finder byWahaj(MTIconData icon) => find.byWidgetPredicate(
  (w) => w is MTIcon && w.icon == icon,
  description: 'Wahaj icon "${icon.name}"',
);
