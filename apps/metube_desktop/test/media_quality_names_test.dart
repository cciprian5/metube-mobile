import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/video_surface_windows.dart';
import 'package:mt_media/mt_media.dart';

/// mpv names a codec its own way; the details rows are shared with the
/// phone, which names them from Android's types. Both say the same words.
void main() {
  test('mpv\'s codec names read as the phone reads them', () {
    String? video(String name) =>
        MediaQuality(videoMime: mimeForMpv(name, video: true)).videoCodec;
    String? audio(String name) =>
        MediaQuality(audioMime: mimeForMpv(name, video: false)).audioCodec;
    expect(video('h264'), 'H.264');
    expect(video('hevc'), 'H.265');
    expect(video('av1'), 'AV1');
    expect(video('vp9'), 'VP9');
    expect(audio('aac'), 'AAC');
    expect(audio('opus'), 'Opus');
    expect(audio('mp3'), 'MP3');
    // One the phone has no word for keeps mpv's, in capitals.
    expect(video('prores'), 'PRORES');
  });
}
