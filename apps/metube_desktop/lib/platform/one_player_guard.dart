/// Refuses a second player for the life of the app.
///
/// media_kit leaves COM uninitialised when a player is disposed, and after
/// a few disposals drag and drop stops working in the whole window. The
/// cure is to never dispose: one player opens clip after clip, and this
/// guard turns a second one into an error at the first test run instead of
/// a broken window weeks later.
abstract final class OnePlayerGuard {
  static bool _taken = false;

  static void claim() {
    if (_taken) {
      throw StateError('The Windows app keeps exactly one player.');
    }
    _taken = true;
  }

  /// For tests only: each test starts as a fresh process would.
  static void resetForTest() => _taken = false;
}
