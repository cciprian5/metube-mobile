import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/file_copy.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/local_copies.dart';
import 'package:metube_desktop/data/notices.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'support/shell_harness.dart';

LibraryItem _clip({bool onServer = true, String? localPath, int? size = 3}) =>
    LibraryItem(
      canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
      title: 'Night Drive',
      onServer: onServer,
      serverFilename: onServer ? 'Night Drive.mp4' : null,
      localPath: localPath,
      sizeBytes: size,
      timestamp: DateTime(2026, 10, 20),
    );

/// The download folder is a test folder; nothing else is asked.
class _Folders extends NoFolders {
  _Folders(this.downloadsPath);

  final String downloadsPath;

  @override
  Future<String?> downloads() async => downloadsPath;

  @override
  Future<String?> videos() async => downloadsPath;
}

/// Windows' notices, kept to be read.
class _Notices implements NoticePort {
  final shown = <EmberNotice>[];

  @override
  Future<void> show(EmberNotice notice) async => shown.add(notice);
}

/// **Copying a clip's file** (owner's request 2026-11-04): the computer's
/// share. Only paths go on the clipboard, a clip on the server is saved
/// into the download folder first, and the same clip is never pulled twice.
void main() {
  const folder = r'C:\Users\me\Downloads';
  int? none(String _) => null;

  group('what a copy takes', () {
    test('a copy on this computer goes on the clipboard as it is', () {
      final plan = planFileCopy(
        _clip(localPath: r'C:\Offline\Night Drive.mp4'),
        localFile: r'C:\Offline\Night Drive.mp4',
        folder: folder,
        lengthOf: none,
        freeBytes: 0,
      );
      expect((plan as CopyNow).path, r'C:\Offline\Night Drive.mp4');
    });

    test('a clip only on the server is saved into the download folder '
        'first', () {
      final plan = planFileCopy(
        _clip(),
        localFile: null,
        folder: folder,
        lengthOf: none,
        freeBytes: null,
      );
      expect(plan, isA<PullFirst>());
      expect((plan as PullFirst).folder, folder);
      expect(plan.large, isFalse);
    });

    test('**the guard**: the same clip already in the download folder is '
        'copied again, not pulled again', () {
      final same = planFileCopy(
        _clip(size: 3),
        localFile: null,
        folder: folder,
        lengthOf: (path) => path == '$folder\\Night Drive.mp4' ? 3 : null,
        freeBytes: null,
      );
      expect((same as CopyNow).path, '$folder\\Night Drive.mp4');
      // Another file that only shares the name is not taken for it.
      final other = planFileCopy(
        _clip(size: 3),
        localFile: null,
        folder: folder,
        lengthOf: (_) => 99,
        freeBytes: null,
      );
      expect(other, isA<PullFirst>());
    });

    test('**the guard**: a drive that cannot hold it says so before a byte '
        'is pulled', () {
      const gigabyte = 1024 * 1024 * 1024;
      final plan = planFileCopy(
        _clip(size: gigabyte),
        localFile: null,
        folder: folder,
        lengthOf: none,
        freeBytes: gigabyte,
      );
      expect((plan as NoSpace).needed, gigabyte);
      expect(plan.free, gigabyte);
    });

    test('above two gigabytes it asks first', () {
      final plan = planFileCopy(
        _clip(size: largeCopyBytes + 1),
        localFile: null,
        folder: folder,
        lengthOf: none,
        freeBytes: null,
      );
      expect((plan as PullFirst).large, isTrue);
    });

    test('no file anywhere, nothing to copy', () {
      expect(
        planFileCopy(
          _clip(onServer: false),
          localFile: null,
          folder: folder,
          lengthOf: none,
          freeBytes: null,
        ),
        isA<NothingToCopy>(),
      );
    });

    test('a pull under way is found, a finished one is not', () {
      LocalCopy copy(CopyPhase phase) => LocalCopy(
        id: 'copy-0',
        kind: CopyKind.download,
        canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
        title: 'Night Drive',
        serverPath: 'Night Drive.mp4',
        folder: folder,
        phase: phase,
      );
      const url = 'https://youtu.be/aaaaaaaaaaa';
      expect(pullUnderWay([copy(CopyPhase.pulling)], url, folder), isNotNull);
      expect(pullUnderWay([copy(CopyPhase.done)], url, folder), isNull);
    });
  });

  group('in the library', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('ember_copy_'));
    tearDown(() => root.deleteSync(recursive: true));

    final notices = _Notices();
    setUp(notices.shown.clear);

    Future<({ShellHarness h, List<List<String>> pasted})> open(
      WidgetTester tester,
      LibraryItem item,
    ) async {
      ShellHarness.useWindow(tester, const Size(1440, 900));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final pasted = <List<String>>[];
      final h = ShellHarness(
        library: [item],
        server: ServerConfig(baseUrl: 'http://nas:8081'),
        overrides: [
          desktopFoldersProvider.overrideWithValue(_Folders(root.path)),
          transferProvider.overrideWithValue(
            (api) => Transfer(api: api, retries: 1, backoff: const []),
          ),
          // Away from the window, where a finished download is announced.
          noticePortProvider.overrideWithValue(notices),
          windowInFrontProvider.overrideWithValue(() async => false),
          filesToClipboardProvider.overrideWithValue((paths) {
            pasted.add(paths);
            return true;
          }),
        ],
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      return (h: h, pasted: pasted);
    }

    Future<void> copyFile(WidgetTester tester) async {
      await tester.tapAt(
        tester.getCenter(find.text('Night Drive')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy file'));
      await tester.pumpAndSettle();
    }

    testWidgets('**the guard**: a clip only on the server is pulled into the '
        'download folder, then its path goes on the clipboard', (tester) async {
      final (:h, :pasted) = await open(tester, _clip());
      h.api.files['Night Drive.mp4'] = [1, 2, 3];
      await copyFile(tester);
      // The pull writes a real file: its steps finish in real time, and
      // each is taken up on the next frame.
      for (var i = 0; i < 200 && pasted.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      // The notice that it is being prepared steps aside first.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(pasted, [
        ['${root.path}\\MeTube Ember\\Night Drive.mp4'],
      ]);
      expect(File(pasted.single.single).readAsBytesSync(), [1, 2, 3]);
      expect(find.textContaining('Ready to paste: Night Drive.mp4'), findsOne);
      // Its own notice says it all: no "saved" from Windows as well.
      expect(notices.shown, isEmpty);
    });

    testWidgets('a copy on this computer goes on the clipboard at once', (
      tester,
    ) async {
      final file = File('${root.path}\\kept.mp4')..writeAsBytesSync([7]);
      final (:h, :pasted) = await open(
        tester,
        _clip(onServer: false, localPath: file.path),
      );
      await copyFile(tester);
      expect(pasted, [
        [file.path],
      ]);
      expect(h.api.files, isEmpty);
    });
  });
}
