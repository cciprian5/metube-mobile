import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

HistoryItem _done(String filename, String folder, int day) =>
    HistoryItem.fromJson({
      'id': filename,
      'title': filename,
      'url': 'https://youtu.be/$filename',
      'status': 'finished',
      'filename': filename,
      'folder': folder,
      'timestamp': DateTime(2026, 10, day).microsecondsSinceEpoch * 1000,
    });

void main() {
  group('FolderChoice', () {
    test('the top is no folder; the channel is named by the server', () {
      expect(FolderChoice.top.isTop, isTrue);
      expect(FolderChoice.channel.isTop, isFalse);
      expect(const FolderChoice('Ai').isTop, isFalse);
    });
  });

  group('pickableFolders', () {
    test('the server and the library together, parents first, tree order', () {
      final server = ServerFolders.fromJson({
        'download_dir': ['Games', 'Ai/Lessons'],
        'audio_download_dir': ['Music'],
      });
      expect(pickableFolders(server, ['Tech Ai 1', 'Ai/Old'], audio: false), [
        'Ai',
        'Ai/Lessons',
        'Ai/Old',
        'Games',
        'Tech Ai 1',
      ]);
      expect(pickableFolders(server, const [], audio: true), ['Music']);
    });

    test('no server answer still offers the folders in use', () {
      expect(pickableFolders(null, ['Kids/Songs'], audio: false), [
        'Kids',
        'Kids/Songs',
      ]);
    });
  });

  group('foldersIgnored', () {
    test('only the newest download into a folder decides', () {
      // Saved at the top despite the folder: the server's outtmpl wins.
      final ignored = _done('../clip.mp4', 'Ai', 20);
      final working = _done('Ai/clip2.mp4', 'Ai', 22);
      expect(foldersIgnored([ignored]), isTrue);
      expect(foldersIgnored([ignored, working]), isFalse);
      expect(foldersIgnored(const []), isFalse);
    });
  });

  group('channelFolderName', () {
    test('one folder, whatever the name holds', () {
      expect(channelFolderName('AC/DC'), 'AC-DC');
      expect(channelFolderName(r'Back\Slash'), 'Back-Slash');
      expect(channelFolderName('  ..  '), '');
      expect(channelFolderName('قناة'), 'قناة');
    });
  });
}
