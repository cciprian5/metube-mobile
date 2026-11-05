import 'package:local_notifier/local_notifier.dart';

import '../data/notices.dart';
import '../identity.dart';

/// **Windows notifications** (`local_notifier`). Windows shows them only
/// for an app it can name, so setting up keeps a Start menu shortcut
/// under the app's name, which also names the app in the media flyout;
/// the installer makes the same one.
class WindowsNotices implements NoticePort {
  WindowsNotices._();

  /// Null when Windows' notifications cannot be reached; the app goes on
  /// without them.
  static Future<WindowsNotices?> start() async {
    try {
      await localNotifier.setup(appName: EmberIdentity.displayName);
      return WindowsNotices._();
    } on Object {
      return null;
    }
  }

  @override
  Future<void> show(EmberNotice notice) async {
    final shown = LocalNotification(
      title: notice.title,
      body: notice.body,
      actions: [
        for (final action in notice.actions)
          LocalNotificationAction(text: action.label),
      ],
    );
    shown
      ..onClick = notice.onClick
      ..onClickAction = (index) {
        if (index >= 0 && index < notice.actions.length) {
          notice.actions[index].onPressed();
        }
      };
    try {
      await localNotifier.notify(shown);
    } on Object {
      // Notifications turned off for the app, or Focus assist: the
      // downloads panel still has it.
    }
  }
}
