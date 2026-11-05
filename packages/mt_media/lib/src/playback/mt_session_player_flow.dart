part of 'mt_session_player.dart';

/// Loading, what follows an item, and recovering from a failure.
///
/// A `part` file for the size limit: these work on the player's private
/// queue and counters, which an extension in another library cannot reach.
extension _MTSessionFlow on MTSessionPlayer {
  Future<void> _skip({required bool forward}) async {
    await _savePosition();
    final moved = forward
        ? _queue.moveNext(_playMode, userInitiated: true)
        : _queue.movePrevious(_playMode);
    if (!moved) return;
    await _loadCurrent(autoPlay: true);
  }

  void _onPhase(MediaPlaybackState phase) {
    if (phase == MediaPlaybackState.completed) unawaited(_onCompleted());
  }

  /// The item ended by itself, so the mode decides what follows.
  Future<void> _onCompleted() async {
    final url = _queue.current?.canonicalUrl;
    if (url != null) await positions.clear(url);
    if (_looping || _playMode == PlayMode.repeatOne) {
      await port.seek(Duration.zero);
      return port.play();
    }
    if (_playMode != PlayMode.stopAtEnd && _queue.moveNext(_playMode)) {
      return _loadCurrent(autoPlay: true);
    }
    await port.pause();
    await port.seek(Duration.zero);
    _broadcast();
  }

  /// Worth waiting for rather than skipping past? **The source decides**:
  /// a stream comes back after a dropped network or a tunnel hiccup, a
  /// local file that will not open is broken.
  bool _isRetryableSource() {
    final item = _queue.current;
    if (item == null) return false;
    return resolver.resolve(item)?.origin == PlaybackOrigin.stream;
  }

  /// The retry budget comes back with **progress**, not with a successful
  /// load: a stream that loads, plays a second and drops would otherwise
  /// be retried for ever.
  void _openRetryBudget() {
    final key = _queue.current?.canonicalUrl;
    final position = port.position;
    final last = _lastRetryPosition;
    if (key != _retryKey ||
        last == null ||
        (position - last).abs() >= MTSessionPlayer.retryBudgetProgress) {
      _networkRetries = 0;
    }
    _retryKey = key;
    _lastRetryPosition = position;
  }

  /// A stream is retried after each wait in [networkRetryBackoff]; only a
  /// source that fails every time is skipped, and repeated skips stop the
  /// session. [autoPlay] is inherited, so a restored session whose first
  /// item fails never starts the next one out loud.
  ///
  /// **A retry picks up at [at]**, where the stream failed. It used to
  /// start the clip over, so a stream that failed at the same minute every
  /// time played its beginning again and again (seen on another computer:
  /// "it reaches a quarter and starts over until it stops").
  Future<void> _onError({bool autoPlay = true, Duration? at}) async {
    _openRetryBudget();
    final resume = at != null && at > Duration.zero ? at : null;
    if (_networkRetries < networkRetryBackoff.length && _isRetryableSource()) {
      final generation = _generation;
      final wait = networkRetryBackoff[_networkRetries];
      _networkRetries++;
      onTrace?.call(
        'stream failed${resume == null ? '' : ' at ${_clock(resume)}'}; '
        'retry $_networkRetries of ${networkRetryBackoff.length} '
        'in ${wait.inSeconds} s',
      );
      await Future<void>.delayed(wait);
      if (_isStale(generation)) return;
      return _loadCurrent(autoPlay: autoPlay, startAt: resume);
    }
    _networkRetries = 0;
    _consecutiveErrors++;
    if (_queue.isEmpty ||
        _consecutiveErrors >= _queue.length ||
        _consecutiveErrors >= MTSessionPlayer.maxConsecutiveSkips) {
      onTrace?.call('failed $_consecutiveErrors in a row; stopped');
      return stop();
    }
    onTrace?.call('failed; skipped to the next');
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _loadCurrent(autoPlay: autoPlay);
    } else {
      await stop();
    }
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _savePosition() async {
    final item = _queue.current;
    // A looping short starts over each time; a position would only spoil
    // the next one.
    if (item == null || _looping) return;
    await positions.save(
      item.canonicalUrl,
      port.position,
      duration: port.duration,
    );
  }

  Future<void> _loadCurrent({required bool autoPlay, Duration? startAt}) async {
    final generation = ++_generation;
    final item = _queue.current;
    if (item == null) return stop();
    final source = resolver.resolve(item);
    if (source == null) return _onError(autoPlay: autoPlay);
    _broadcast();
    // A restored session continues exactly; a saved position only for
    // something long. With the length unknown the position is taken, and
    // dropped after loading if the item turns out short.
    final saved = startAt == null
        ? await positions.positionOf(item.canonicalUrl)
        : null;
    final known = item.duration;
    final keepSaved =
        known == null || known >= MTSessionPlayer.resumeMinimumLength;
    final resume = startAt ?? (keepSaved ? saved : null) ?? Duration.zero;
    if (_isStale(generation)) return;
    try {
      await port.setSource(source, initialPosition: resume);
      if (_isStale(generation)) return;
      _consecutiveErrors = 0;
      final duration = port.duration;
      if (known == null &&
          saved != null &&
          startAt == null &&
          duration != null &&
          duration < MTSessionPlayer.resumeMinimumLength) {
        await port.seek(Duration.zero);
        if (_isStale(generation)) return;
      }
      if (autoPlay) await port.play();
      if (_isStale(generation)) return;
      _broadcast();
      await persist();
    } on Object catch (e) {
      if (_isStale(generation)) return;
      onTrace?.call('load failed: $e');
      // A retry that failed to load tries the same place again.
      await _onError(autoPlay: autoPlay, at: startAt);
    }
  }

  /// "Play next": into the queue after what plays, which goes on playing.
  /// The same clip as the one playing changes nothing, rather than queue
  /// it to play twice in a row.
  Future<void> _playNext(PlaylistItem item) async {
    if (_queue.isEmpty) return playItems([item]);
    if (_queue.current?.canonicalUrl == item.canonicalUrl) return;
    _queue.insertNext(item);
    _broadcast();
    await persist();
  }
}
