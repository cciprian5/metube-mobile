import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Back and forward through the places visited, as in a browser.
///
/// go_router's own stack has nothing to go back to here: every place is
/// opened with `go`, which replaces it. So the trail is kept beside the
/// router, and moving along it is not recorded as a new visit.
class NavHistory extends ChangeNotifier {
  NavHistory._(this._router) {
    _visit(_location());
    _router.routerDelegate.addListener(_onRoute);
  }

  /// Follows [router] from its current place on.
  factory NavHistory.of(GoRouter router) => NavHistory._(router);

  final GoRouter _router;
  final List<String> _trail = [];
  int _index = -1;
  String? _moving;

  /// The longest trail kept; older places fall off its start.
  static const limit = 50;

  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _trail.length - 1;

  String _location() =>
      _router.routerDelegate.currentConfiguration.uri.toString();

  void _onRoute() {
    final now = _location();
    if (now == _moving) {
      _moving = null;
      notifyListeners();
      return;
    }
    _visit(now);
  }

  void _visit(String location) {
    if (_index >= 0 && _trail[_index] == location) return;
    // A new visit after going back drops the places ahead, as a browser
    // does.
    _trail
      ..removeRange(_index + 1, _trail.length)
      ..add(location);
    if (_trail.length > limit) _trail.removeAt(0);
    _index = _trail.length - 1;
    notifyListeners();
  }

  void back() => _move(-1);
  void forward() => _move(1);

  void _move(int step) {
    final to = _index + step;
    if (to < 0 || to >= _trail.length) return;
    _index = to;
    _moving = _trail[to];
    _router.go(_trail[to]);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }
}
