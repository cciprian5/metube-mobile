import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// Opens a dialog the way Ember's dialogs open: **it grows from a hair
/// smaller as it fades in, and leaves quicker than it came**. Flutter's own
/// only faded, in the same short time each way, so the add-link dialog, the
/// first thing a new user opens, arrived as a flat cut.
Future<T?> showEmberDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _EmberDialogRoute<T>(
      opening: mtMotionDuration(context, MTMotion.page),
      closing: mtMotionDuration(context, MTMotion.fast),
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // The charcoal of the full-screen player, thinned: dark behind a
      // dialog by day and by night alike.
      barrierColor: MTPalette.fullscreenScrim.withValues(alpha: _scrim),
      pageBuilder: (context, _, _) =>
          SafeArea(child: Builder(builder: builder)),
      transitionBuilder: (context, motion, _, child) {
        final closing = motion.status == AnimationStatus.reverse;
        final eased = CurvedAnimation(
          parent: motion,
          curve: closing ? MTMotion.exit : MTMotion.entrance,
        );
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: _from, end: 1).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
}

/// A dialog route whose closing has its own, shorter time.
class _EmberDialogRoute<T> extends RawDialogRoute<T> {
  _EmberDialogRoute({
    required Duration opening,
    required this.closing,
    required super.pageBuilder,
    required super.transitionBuilder,
    super.barrierDismissible,
    super.barrierLabel,
    super.barrierColor,
  }) : super(transitionDuration: opening);

  final Duration closing;

  @override
  Duration get reverseTransitionDuration => closing;
}

/// The size a dialog grows from.
const double _from = 0.96;

/// How strongly the window behind a dialog is darkened.
const double _scrim = 0.45;
