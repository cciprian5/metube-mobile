import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mt_core/mt_core.dart';

/// Writes every error no code caught to the diagnostic log, as the phone
/// apps do: a crash in a released build otherwise reaches only a console
/// nobody has open. A few lines of the stack say where.
void logEveryError(MTLogger logger) {
  final present = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(
      logger.error(
        '${details.exceptionAsString()} | ${errorPlace(details)}',
        tag: 'crash',
      ),
    );
    present?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(logger.error('$error | ${_where(stack)}', tag: 'crash'));
    // Not handled here: the platform still reports it as before.
    return false;
  };
}

/// Where a Flutter error happened, for the log: a few lines of its stack,
/// or, for a layout error such as an overflow, which carries no stack, the
/// widget Flutter names as its cause (with its file and line in debug
/// builds). Without it the log said only "overflowed by 15 pixels", and
/// not where.
String errorPlace(FlutterErrorDetails details) {
  final stack = _where(details.stack);
  if (stack.isNotEmpty) return stack;
  const marker = 'The relevant error-causing widget was';
  final text = details.toString();
  final at = text.indexOf(marker);
  if (at < 0) return '';
  final rest = text.substring(at + marker.length).split('\n');
  // The widget, then where it was written, up to the next blank line.
  return rest
      .skip(1)
      .takeWhile((line) => line.trim().isNotEmpty)
      .map((line) => line.trim())
      .join(' ');
}

String _where(StackTrace? stack) => mtStackPlace(stack?.toString());
