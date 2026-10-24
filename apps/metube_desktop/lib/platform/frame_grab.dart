import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/generated/libmpv/bindings.dart';

/// One picture from a video on the server, for a clip the server names no
/// cover for (every Instagram, TikTok or X video). Windows has nothing like
/// Android's media retriever, so it is taken by **the libmpv the player
/// already ships**: a bare engine, not a `Player`, with no window, no
/// sound, no media keys and nothing shown, made for one frame and destroyed.
///
/// Measured on the owner's server: 8 of 8 videos in a fifth of a second at
/// home and a second through the tunnel, about 100 KB each; the engine
/// holds about 200 MB for that moment. It runs on its own isolate, since
/// libmpv's event wait blocks.
///
/// Safe by construction: [url] is the server's own file and [headers] its
/// own credentials, the same pair the player already streams with, so the
/// password goes nowhere else. The engine reads no config file and loads
/// no scripts (this build has no Lua, and JavaScript is never loaded), and
/// it decodes what the player would decode anyway.
Future<Uint8List?> grabFrame(String url, Map<String, String> headers) async {
  final header = [
    for (final MapEntry(:key, :value) in headers.entries)
      // The option is a comma-separated list; a value with a comma in it
      // would be cut in two and sent half-formed.
      if (!value.contains(',') && !key.contains(',')) '$key: $value',
  ].join(',');
  final out = await Directory.systemTemp.createTemp('ember_frame_');
  try {
    final dir = out.path;
    // One second in skips a black first frame; a clip shorter than that is
    // asked again from its start.
    for (final start in const ['1', '0']) {
      await Isolate.run(() => _grab(url, header, dir, start))
          .timeout(_wait + const Duration(seconds: 15));
      final pictures = out.listSync().whereType<File>().toList();
      if (pictures.isEmpty) continue;
      final bytes = await pictures.first.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    }
    return null;
  } on Object {
    return null;
  } finally {
    unawaited(out.delete(recursive: true).then((_) {}, onError: (_) {}));
  }
}

/// Longest a single clip may take before it is given up on.
const _wait = Duration(seconds: 30);

void _grab(String url, String header, String dir, String start) {
  final mpv = MPV(DynamicLibrary.open('libmpv-2.dll'));
  final handle = mpv.mpv_create();
  if (handle == nullptr) return;
  final kept = <Pointer>[];
  Pointer<Int8> text(String s) {
    final p = s.toNativeUtf8(allocator: calloc).cast<Int8>();
    kept.add(p);
    return p;
  }

  try {
    const options = {
      'config': 'no',
      'load-scripts': 'no',
      'terminal': 'no',
      'msg-level': 'all=no',
      'input-default-bindings': 'no',
      'input-vo-keyboard': 'no',
      'vo': 'image',
      'ao': 'null',
      'audio': 'no',
      'sid': 'no',
      'sub-auto': 'no',
      'audio-file-auto': 'no',
      'cover-art-auto': 'no',
      'hwdec': 'no',
      'cache': 'no',
      'demuxer-max-bytes': '4MiB',
      'demuxer-max-back-bytes': '0',
      'network-timeout': '15',
      'hr-seek': 'no',
      'frames': '1',
      'vo-image-format': 'jpg',
      'vo-image-jpeg-quality': '60',
    };
    for (final MapEntry(:key, :value) in options.entries) {
      mpv.mpv_set_option_string(handle, text(key), text(value));
    }
    mpv.mpv_set_option_string(handle, text('start'), text(start));
    mpv.mpv_set_option_string(handle, text('vo-image-outdir'), text(dir));
    if (header.isNotEmpty) {
      mpv.mpv_set_option_string(
        handle,
        text('http-header-fields'),
        text(header),
      );
    }
    if (mpv.mpv_initialize(handle) < 0) return;
    final args = calloc<Pointer<Int8>>(3);
    kept.add(args);
    args[0] = text('loadfile');
    args[1] = text(url);
    args[2] = nullptr;
    if (mpv.mpv_command(handle, args) < 0) return;
    final clock = Stopwatch()..start();
    while (clock.elapsed < _wait) {
      final id = mpv.mpv_wait_event(handle, 1).ref.event_id;
      if (id == mpv_event_id.MPV_EVENT_END_FILE ||
          id == mpv_event_id.MPV_EVENT_SHUTDOWN) {
        break;
      }
    }
  } finally {
    mpv.mpv_terminate_destroy(handle);
    for (final p in kept) {
      calloc.free(p);
    }
  }
}
