import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/copy_names.dart';
import 'package:mt_core/mt_core.dart';

/// A download keeps the server's folder below the download folder, and the
/// folder is made before the file is fetched: the server's word must never
/// make it anywhere else.
void main() {
  test('**the guard**: a server folder that climbs makes no folder at all', () {
    final path = ServerPath.of(folder: '../../../Evil', filename: 'clip.mp4')!;
    expect(serverSubfolder(path), '');
  });

  test('the server folder is kept, nested, with names Windows takes', () {
    expect(
      serverSubfolder(ServerPath.of(folder: 'Kids/Songs', filename: 'a.mp4')!),
      r'Kids\Songs',
    );
    expect(
      serverSubfolder(ServerPath.of(folder: 'A: B?', filename: 'a.mp4')!),
      'A_ B_',
    );
    expect(serverSubfolder(ServerPath.of(filename: 'a.mp4')!), '');
    expect(
      serverSubfolder(
        ServerPath.of(folder: 'Music', filename: 'a.m4a', audio: true)!,
      ),
      'Music',
    );
  });
}
