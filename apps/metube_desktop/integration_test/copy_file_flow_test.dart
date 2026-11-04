import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:metube_desktop/data/file_copy.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/platform/file_clipboard_windows.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import '../test/support/shell_harness.dart';

class _Folders extends NoFolders {
  _Folders(this.path);

  final String path;

  @override
  Future<String?> downloads() async => path;

  @override
  Future<String?> videos() async => path;
}

/// "Copy file" from the clip's menu to **Windows' real clipboard**: the
/// library and the server are the test's, the clipboard, the drive and the
/// file written are this computer's. Run on Windows:
///
///     flutter test integration_test/copy_file_flow_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String> clipboardFiles() async {
    final read = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      '[Console]::OutputEncoding=[Text.Encoding]::UTF8;'
          r'(Get-Clipboard -Format FileDropList) | % { $_.FullName }',
    ]);
    return (read.stdout as String).trim();
  }

  testWidgets('**the guard**: a clip only on the server is saved into the '
      'download folder, and Windows can paste it', (tester) async {
    final before = await Clipboard.getData(Clipboard.kTextPlain);
    addTearDown(() async {
      await Clipboard.setData(ClipboardData(text: before?.text ?? ''));
    });
    final root = Directory.systemTemp.createTempSync('ember_copy_flow_');
    addTearDown(() => root.deleteSync(recursive: true));
    const bytes = [1, 2, 3, 4, 5];
    ShellHarness.useWindow(tester, const Size(1440, 900));
    // This computer is in Arabic; the words looked for are English.
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final h = ShellHarness(
      library: [
        LibraryItem(
          canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
          title: 'Night Drive',
          onServer: true,
          serverFilename: 'Night Drive.mp4',
          sizeBytes: bytes.length,
          timestamp: DateTime(2026, 11, 4),
        ),
      ],
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        desktopFoldersProvider.overrideWithValue(_Folders(root.path)),
        filesToClipboardProvider.overrideWithValue(putFilesOnClipboard),
        freeBytesProvider.overrideWithValue(freeBytesAt),
      ],
    );
    h.api.files['Night Drive.mp4'] = bytes;
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tapAt(
      tester.getCenter(find.text('Night Drive')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy file'));
    final saved = '${root.path}\\MeTube\\Night Drive.mp4';
    for (var i = 0; i < 300 && !File(saved).existsSync(); i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(seconds: 1));

    expect(File(saved).readAsBytesSync(), bytes);
    expect(await tester.runAsync(clipboardFiles), saved);
    expect(find.textContaining('Ready to paste'), findsOneWidget);
  });
}
