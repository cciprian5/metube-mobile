import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';

/// The two tips the app gives on its own, each once in a lifetime.
enum EmberHint {
  /// The keyboard shortcuts, as the first clip plays.
  shortcuts,

  /// The icon by the clock, the first time the window closes to it.
  tray,
}

/// Whether tips are on, and which have been seen or made needless.
class HintsState {
  const HintsState({this.on = true, this.seen = const {}});

  final bool on;
  final Set<EmberHint> seen;
}

final hintsProvider = NotifierProvider<Hints, HintsState>(Hints.new);

/// **Tips that never get in the way**: each shows once, and never to
/// someone who already found the thing by themselves (a shortcut used
/// marks the shortcuts tip as needless); none at start-up, and none in a
/// session that already interrupted once (the server setup, "what's new"
/// or an update notice). Settings turns them off or shows them again.
class Hints extends Notifier<HintsState> {
  static const onKey = 'ember_hints_on';
  static const seenKey = 'ember_hints_seen';

  /// Read from the store; until then nothing is offered, and what is
  /// learned or seen waits for it, so the read cannot undo it.
  bool _loaded = false;
  late Future<void> _ready;

  /// Something has already interrupted this session.
  bool _interrupted = false;

  @override
  HintsState build() {
    // Built again, it is a new session: read afresh, nothing interrupted.
    _loaded = false;
    _interrupted = false;
    _ready = _load();
    return const HintsState();
  }

  Future<void> _load() async {
    final store = ref.read(keyValueStoreProvider);
    final names = (await store.getString(seenKey) ?? '').split(',');
    state = HintsState(
      on: await store.getBool(onKey) ?? true,
      seen: {
        for (final hint in EmberHint.values)
          if (names.contains(hint.name)) hint,
      },
    );
    _loaded = true;
  }

  /// Whether [hint] may show now. The tray's comes as the window goes, so
  /// it interrupts nothing and the session's one interruption does not
  /// hold it back.
  bool wants(EmberHint hint) =>
      _loaded &&
      state.on &&
      !state.seen.contains(hint) &&
      (hint == EmberHint.tray || !_interrupted);

  /// The session has already asked for the user's attention once.
  void interrupted() => _interrupted = true;

  /// [hint] was shown: never again, and nothing more in the window this
  /// session.
  Future<void> shown(EmberHint hint) async {
    if (hint != EmberHint.tray) _interrupted = true;
    await _ready;
    await _see({...state.seen, hint});
  }

  /// The user found the thing by themselves: no tip for it.
  Future<void> learned(EmberHint hint) async {
    await _ready;
    if (state.seen.contains(hint)) return;
    await _see({...state.seen, hint});
  }

  Future<void> setOn(bool on) async {
    await _ready;
    state = HintsState(on: on, seen: state.seen);
    final store = ref.read(keyValueStoreProvider);
    await ref.read(prefsMutexProvider).run(() => store.setBool(onKey, on));
  }

  /// Every tip may show again, from the next session's moments.
  Future<void> showAgain() async {
    await _ready;
    await _see(const {});
  }

  Future<void> _see(Set<EmberHint> seen) async {
    state = HintsState(on: state.on, seen: seen);
    final store = ref.read(keyValueStoreProvider);
    await ref
        .read(prefsMutexProvider)
        .run(() => store.setString(seenKey, seen.map((h) => h.name).join(',')));
  }
}
