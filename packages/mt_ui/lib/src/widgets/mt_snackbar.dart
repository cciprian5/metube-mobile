import 'package:flutter/material.dart';

import '../wahaj/mt_notice.dart';
import 'mt_route_motion.dart';

enum MTSnackType { info, success, error }

/// How long a snack bar stays: one duration for all of them, with or
/// without an action.
const mtSnackDuration = Duration(seconds: 4);

/// One SnackBar style, the Wahaj notice the computer uses ([MTNotice]): a
/// bar on the edge for its state, and a line along the bottom running out
/// with the time it stays, and an optional undo.
void showMTSnack(
  BuildContext context,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = mtSnackDuration,
  bool logged = false,
}) => showMTSnackOn(
  ScaffoldMessenger.of(context),
  message,
  type: type,
  actionLabel: actionLabel,
  onAction: onAction,
  themeContext: context,
  duration: duration,
  logged: logged,
);

/// Where every error shown in a snack bar is written down. The app points
/// it at its diagnostic log at startup; this package knows no log.
///
/// It catches the errors no one logged on purpose: a message shown is a
/// message a user may ask about, and the log should hold it too. A caller
/// that already logged the error itself passes `logged: true`, so it is
/// not written twice.
void Function(String message)? mtErrorSnackLog;

/// The same, with a **pre-captured** messenger. Used when the original
/// context has already been deactivated, such as a bottom sheet that just
/// closed: looking up `ScaffoldMessenger` through a deactivated context
/// trips the `_dependents.isEmpty` assertion.
void showMTSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  BuildContext? themeContext,
  Duration duration = mtSnackDuration,
  bool logged = false,
}) {
  if (type == MTSnackType.error && !logged) mtErrorSnackLog?.call(message);
  final kind = switch (type) {
    MTSnackType.success => MTNoticeKind.done,
    MTSnackType.error => MTNoticeKind.failed,
    MTSnackType.info => MTNoticeKind.info,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // **It dismisses itself even when it has an action** (field report
        // 2026-09-04: "the notices that appear over the add-link button
        // never go away"). In Flutter, `persist = persist ?? action !=
        // null`, so every bar with a button, such as "download started ·
        // change quality", stayed **forever** until the user swiped it
        // away, while "added to favourites" with no action vanished after
        // four seconds. The decision: one duration for all.
        persist: false,
        duration: duration,
        padding: EdgeInsets.zero,
        // The notice draws its own action, so the time line runs under it
        // as well.
        content: MTNotice(
          message: message,
          kind: kind,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
        ),
      ),
      snackBarAnimationStyle: mtNoticeMotion(
        still:
            MediaQuery.maybeDisableAnimationsOf(
              themeContext ?? messenger.context,
            ) ??
            false,
      ),
    );
}
