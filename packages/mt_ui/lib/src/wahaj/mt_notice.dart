import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icon_data.dart';
import '../icons/mt_icons.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// What a notice reports, which sets its colour.
enum MTNoticeKind { done, failed, info }

/// The Wahaj notice at the foot of the window. The state is **a bar on the
/// edge**, not a coloured circle; the icon says the action itself (a check,
/// a cross, a copy); and a line along the bottom shrinks until the notice
/// leaves, so the user can see how long it will stay.
void showMTNotice(
  BuildContext context, {
  required String message,
  MTNoticeKind kind = MTNoticeKind.info,
  MTIconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final p = MTThemeX.of(context).palette;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        padding: EdgeInsets.zero,
        backgroundColor: p.miniBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTCorners.desktop.card),
        ),
        content: MTNotice(
          message: message,
          kind: kind,
          icon: icon,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration,
        ),
      ),
    );
}

class MTNotice extends StatelessWidget {
  const MTNotice({
    super.key,
    required this.message,
    this.kind = MTNoticeKind.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 4),
  });

  final String message;
  final MTNoticeKind kind;

  /// Defaults to a check for done, a cross for failed, nothing for info.
  final MTIconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// How long the bottom line takes to run out.
  final Duration duration;

  static Color stateColor(MTPalette p, MTNoticeKind kind) => switch (kind) {
    MTNoticeKind.done => p.ok,
    MTNoticeKind.failed => p.err,
    MTNoticeKind.info => p.accent,
  };

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final state = stateColor(p, kind);
    final shown =
        icon ??
        switch (kind) {
          MTNoticeKind.done => MTIcons.check,
          MTNoticeKind.failed => MTIcons.close,
          MTNoticeKind.info => null,
        };
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(MTCorners.desktop.card),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              MTSpace.lg,
              MTSpace.sm,
              MTSpace.sm,
              MTSpace.md,
            ),
            child: Row(
              children: [
                if (shown != null) ...[
                  MTIcon(shown, size: 18, color: state),
                  const SizedBox(width: MTSpace.sm),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: text.bodyMedium!.copyWith(
                      color: p.miniInk,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                      onAction?.call();
                    },
                    // Sized for a pointer: Material's 48-point touch target
                    // would make a notice with an action taller than one
                    // without.
                    style: TextButton.styleFrom(
                      foregroundColor: p.night ? p.accentInk : p.accent,
                      textStyle: text.labelLarge,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MTSpace.sm,
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
          // The state bar on the leading edge.
          PositionedDirectional(
            start: 0,
            top: MTSpace.sm,
            bottom: MTSpace.sm,
            child: Container(
              key: const ValueKey('state-bar'),
              width: 3,
              decoration: BoxDecoration(
                color: state,
                borderRadius: BorderRadiusDirectional.horizontal(
                  end: Radius.circular(MTCorners.desktop.box / 2),
                ),
              ),
            ),
          ),
          // The time left, running out towards the start.
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : duration,
              builder: (context, left, _) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  key: const ValueKey('time-left'),
                  widthFactor: left,
                  child: Container(
                    height: 1.5,
                    color: state.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
