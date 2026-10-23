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
        '${details.exceptionAsString()} | ${_where(details.stack)}',
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

String _where(StackTrace? stack) => (stack?.toString() ?? '')
    .split('\n')
    .take(4)
    .map((line) => line.trim())
    .join(' | ');
