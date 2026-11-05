/// The names Windows shows for the app. **Fixed for good at the first
/// release**: the data folder is derived from them, so a later rename
/// would leave every user's settings, tags and playlists behind in the old
/// folder.
abstract final class EmberIdentity {
  /// The window title, the media flyout and the tray.
  ///
  /// It is also the data folder: `%APPDATA%\MeTube Ember\` for settings
  /// and `%LOCALAPPDATA%\MeTube Ember\` for logs and caches. path_provider
  /// builds those from the ProductName in `windows/runner/Runner.rc`,
  /// prefixed by the CompanyName when there is one, which is why that
  /// field stays empty. A test holds the runner to this value.
  static const displayName = 'MeTube Ember';

  /// The diagnostic log's file name, inside the local data folder.
  static const logFile = 'metube_ember.log';
}
