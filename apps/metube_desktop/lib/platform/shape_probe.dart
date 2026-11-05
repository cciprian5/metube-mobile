import 'dart:ffi';
import 'dart:isolate';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';

import '../data/shapes/shapes_data.dart';

/// A clip's length and picture shape, read from its file's header, so the
/// library shows how long every clip is before it is ever played.
///
/// The phone has Android's media retriever for this; Windows has nothing
/// like it, so it is read by **the libmpv the player already ships**, a
/// bare engine as for a cover's frame (`grabFrame`): no window, no sound,
/// nothing decoded to show, and destroyed once the file is open. It reads
/// what opening the file needs, a few hundred kilobytes, not the clip.
///
/// Safe by construction, like the frame: [url] is the server's own file
/// and [headers] its own credentials, and the engine loads no config and
/// no scripts.
Future<ProbedShape?> probeShape(String url, Map<String, String> headers) {
  final header = [
    for (final MapEntry(:key, :value) in headers.entries)
      if (!value.contains(',') && !key.contains(',')) '$key: $value',
  ].join(',');
  return Isolate.run(() => _probe(url, header))
      .timeout(_wait + const Duration(seconds: 10), onTimeout: () => null);
}

/// Longest one clip may take before it is given up on.
const _wait = Duration(seconds: 20);

ProbedShape? _probe(String url, String header) {
  final mpv = MPV(DynamicLibrary.open('libmpv-2.dll'));
  final handle = mpv.mpv_create();
  if (handle == nullptr) return null;
  final kept = <Pointer>[];
  Pointer<Int8> text(String s) {
    final p = s.toNativeUtf8(allocator: calloc).cast<Int8>();
    kept.add(p);
    return p;
  }

  String? stringOf(String property) {
    final value = mpv.mpv_get_property_string(handle, text(property));
    if (value == nullptr) return null;
    try {
      return value.cast<Utf8>().toDartString();
    } finally {
      mpv.mpv_free(value.cast());
    }
  }

  double? number(String property) => double.tryParse(stringOf(property) ?? '');

  try {
    const options = {
      'config': 'no',
      'load-scripts': 'no',
      'terminal': 'no',
      'msg-level': 'all=no',
      'input-default-bindings': 'no',
      'input-vo-keyboard': 'no',
      'vo': 'null',
      'ao': 'null',
      'audio': 'no',
      'sid': 'no',
      'sub-auto': 'no',
      'audio-file-auto': 'no',
      'cover-art-auto': 'no',
      'hwdec': 'no',
      'pause': 'yes',
      'cache': 'no',
      'demuxer-max-bytes': '2MiB',
      'demuxer-max-back-bytes': '0',
      'demuxer-readahead-secs': '0',
      'network-timeout': '15',
    };
    for (final MapEntry(:key, :value) in options.entries) {
      mpv.mpv_set_option_string(handle, text(key), text(value));
    }
    if (header.isNotEmpty) {
      mpv.mpv_set_option_string(
        handle,
        text('http-header-fields'),
        text(header),
      );
    }
    if (mpv.mpv_initialize(handle) < 0) return null;
    final args = calloc<Pointer<Int8>>(3);
    kept.add(args);
    args[0] = text('loadfile');
    args[1] = text(url);
    args[2] = nullptr;
    if (mpv.mpv_command(handle, args) < 0) return null;
    final clock = Stopwatch()..start();
    while (clock.elapsed < _wait) {
      final id = mpv.mpv_wait_event(handle, 1).ref.event_id;
      if (id == mpv_event_id.MPV_EVENT_FILE_LOADED) {
        final seconds = number('duration');
        if (seconds == null || seconds <= 0) return null;
        // The demuxer's own size, known as soon as the file is open; none
        // for sound alone. A song's embedded cover is a "video" track to
        // the engine, and a portrait cover would send a song down the
        // shorts path, so its shape is not the clip's.
        final song = stringOf('current-tracks/video/albumart') == 'yes';
        final width = song ? null : number('current-tracks/video/demux-w');
        final height = song ? null : number('current-tracks/video/demux-h');
        return ProbedShape(
          duration: Duration(milliseconds: (seconds * 1000).round()),
          aspectRatio: width != null && height != null && height > 0
              ? width / height
              : null,
        );
      }
      if (id == mpv_event_id.MPV_EVENT_END_FILE ||
          id == mpv_event_id.MPV_EVENT_SHUTDOWN) {
        return null;
      }
    }
    return null;
  } finally {
    mpv.mpv_terminate_destroy(handle);
    for (final p in kept) {
      calloc.free(p);
    }
  }
}
