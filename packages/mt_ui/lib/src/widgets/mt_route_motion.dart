import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'mt_desktop_app.dart';

/// Sheets, dialogs and notices on the phones move at the app's own pace
/// rather than Flutter's: they come in on the entrance curve and leave
/// faster than they came. The computer keeps what it has.
///
/// Null on the computer; no motion at all when the system asks for none.
AnimationStyle? mtSheetMotion(BuildContext context) {
  if (MTDesktopApp.isDesktop(context)) return null;
  if (MediaQuery.disableAnimationsOf(context)) {
    return AnimationStyle.noAnimation;
  }
  return const AnimationStyle(
    duration: MTMotion.medium,
    reverseDuration: MTMotion.leave,
    curve: MTMotion.entrance,
    reverseCurve: MTMotion.exit,
  );
}

/// The notice at the foot of a phone screen: in with a page, out quickly.
AnimationStyle mtNoticeMotion({required bool still}) => still
    ? AnimationStyle.noAnimation
    : const AnimationStyle(
        duration: MTMotion.page,
        reverseDuration: MTMotion.fast,
      );

/// Every bottom sheet in the phone apps goes through here, so none of them
/// rises at Flutter's default pace.
Future<T?> showMTSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  BoxConstraints? constraints,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: isScrollControlled,
  useRootNavigator: useRootNavigator,
  useSafeArea: useSafeArea,
  constraints: constraints,
  sheetAnimationStyle: mtSheetMotion(context),
);

/// Every dialog in the phone apps goes through here: it grows a little
/// from [MTMotion.recede] as it fades in, and goes back faster. The
/// computer keeps Flutter's dialog.
Future<T?> showMTDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (MTDesktopApp.isDesktop(context)) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(
    _MTDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      still: MediaQuery.disableAnimationsOf(context),
    ),
  );
}

class _MTDialogRoute<T> extends DialogRoute<T> {
  _MTDialogRoute({
    required super.context,
    required super.builder,
    required super.barrierDismissible,
    required super.barrierColor,
    required super.themes,
    required this.still,
  }) : super(
         animationStyle: still
             ? AnimationStyle.noAnimation
             : const AnimationStyle(
                 duration: MTMotion.page,
                 curve: MTMotion.entrance,
                 reverseCurve: MTMotion.exit,
               ),
       );

  final bool still;

  // A dialog route closes at its opening pace unless told otherwise.
  @override
  Duration get reverseTransitionDuration =>
      still ? Duration.zero : MTMotion.fast;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final faded = super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
    if (still) return faded;
    if (_grow?.parent != animation) {
      _grow?.dispose();
      _grow = CurvedAnimation(
        parent: animation,
        curve: MTMotion.entrance,
        reverseCurve: MTMotion.exit,
      );
    }
    return ScaleTransition(
      scale: Tween(begin: MTMotion.recede, end: 1.0).animate(_grow!),
      child: faded,
    );
  }

  // Kept across builds: a curve made per build would leave a listener on
  // the route's animation every frame.
  CurvedAnimation? _grow;

  @override
  void dispose() {
    _grow?.dispose();
    super.dispose();
  }
}
