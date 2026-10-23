import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/transcripts_data.dart';
import 'package:mt_transcripts/mt_transcripts.dart';

void main() {
  late Directory dir;
  late TranscriptStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ember_transcripts_');
    store = TranscriptStore(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Transcript said(String language) => Transcript(
    canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
    language: language,
    source: 'sidecar',
    fetchedAt: DateTime(2026, 10, 24),
    segments: [
      TranscriptSegment(
        start: Duration.zero,
        end: const Duration(seconds: 3),
        text: 'said in $language',
      ),
    ],
  );

  Future<Transcript?> read(TranscriptStore? on) {
    final container = ProviderContainer(
      overrides: [transcriptStoreProvider.overrideWithValue(on)],
    );
    addTearDown(container.dispose);
    return container.read(
      transcriptForProvider((
        canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
        serverFilename: null,
      )).future,
    );
  }

  test('a transcript kept on this computer is read from there', () async {
    await store.write(said('ar'));
    expect((await read(store))!.segments.single.text, 'said in ar');
  });

  test("with several, the reader's language wins over the rest", () async {
    // The test machine reads English.
    await store.write(said('de'));
    await store.write(said('en'));
    expect((await read(store))!.language, 'en');
  });

  test('none kept and no server: no transcript, no error', () async {
    expect(await read(store), isNull);
    expect(await read(null), isNull);
  });
}
