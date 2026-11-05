import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ember closed with no message, twice on one machine, a moment after a clip
/// of other dimensions opened. Both crash dumps showed media_kit_video's
/// frame callback throwing `std::out_of_range` from `at` inside the engine's
/// noexcept call: the plugin stores a new texture's id before it adds the
/// texture, and a frame asked for in between found nothing. The patched copy
/// in third_party looks the id up instead; see its PATCHES.md.
void main() {
  final root = Directory.current.parent.parent.path;
  String read(String path) => File('$root/$path').readAsStringSync();

  test('**the guard**: the app builds against the patched media_kit_video', () {
    final pubspec = read('pubspec.yaml');
    expect(
      RegExp(
        r'dependency_overrides:[\s\S]*media_kit_video:\s*\n\s*path: third_party/media_kit_video',
      ).hasMatch(pubspec),
      isTrue,
      reason: 'without the override the original, which crashes, is built',
    );
  });

  test('**the guard**: no texture is looked up with at, which throws', () {
    final source = read('third_party/media_kit_video/windows/video_output.cc');
    expect(
      RegExp(r'textures_\.at\(').hasMatch(source),
      isFalse,
      reason: 'a throw in the frame callback ends the process',
    );
    expect(
      RegExp(r'textures_\.find\(texture_id_\)').allMatches(source).length,
      greaterThanOrEqualTo(4),
    );
  });
}
