import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/data/file_copy.dart';
import 'package:metube_desktop/data/folders_data.dart';
import 'package:metube_desktop/data/library_data.dart';
import 'package:metube_desktop/features/library/choose_mark.dart';
import 'package:metube_desktop/shell/sidebar.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import 'support/shell_harness.dart';

class _Folders extends NoFolders {
  _Folders(this.downloadsPath);

  final String downloadsPath;

  @override
  Future<String?> downloads() async => downloadsPath;
}

/// The owner's report of 2026-11-05: Ctrl Shift C did nothing with the
/// mouse, since the clip keys answered only a clip with keyboard focus, and
/// a click opens a clip rather than focusing it. The two copy keys now take
/// the one clip chosen, else the one under the mouse; the other clip keys
/// stay with focus alone.
void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('ember_keys_'));
  tearDown(() => root.deleteSync(recursive: true));

  LibraryItem clip(String title, String id) => LibraryItem(
    canonicalUrl: 'https://youtu.be/$id',
    title: title,
    onServer: false,
    localPath: (File('${root.path}\\$title.mp4')..writeAsBytesSync([1])).path,
    sizeBytes: 1,
    timestamp: DateTime(2026, 10, 20),
  );

  late List<String> links;
  late List<List<String>> files;
  late TestGesture mouse;

  Future<List<LibraryItem>> open(WidgetTester tester) async {
    ShellHarness.useWindow(tester, const Size(1440, 900));
    links = [];
    files = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          links.add((call.arguments as Map)['text'] as String);
        }
        return call.method == 'Clipboard.getData'
            ? <String, Object?>{'text': ''}
            : null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final items = [
      clip('Night Drive', 'aaaaaaaaaaa'),
      clip('Amber Skies', 'bbbbbbbbbbb'),
      clip('Low Tide', 'ccccccccccc'),
    ];
    final h = ShellHarness(
      library: items,
      server: ServerConfig(baseUrl: 'http://nas:8081'),
      overrides: [
        desktopFoldersProvider.overrideWithValue(_Folders(root.path)),
        filesToClipboardProvider.overrideWithValue((paths) {
          files.add(paths);
          return true;
        }),
      ],
    );
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    // One mouse for the whole test, as on a desk.
    mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    return items;
  }

  Future<void> mouseOver(WidgetTester tester, String title) async {
    await mouse.moveTo(tester.getCenter(find.text(title)));
    await tester.pumpAndSettle();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool control = false,
    bool shift = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> chooseByMark(WidgetTester tester, String title) async {
    await mouseOver(tester, title);
    final mark = find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(ChooseMark),
      ),
      matching: find.byKey(ChooseMark.markKey),
    );
    await mouse.moveTo(tester.getCenter(mark));
    await mouse.down(tester.getCenter(mark));
    await mouse.up();
    await tester.pumpAndSettle();
  }

  testWidgets('**the guard**: with the mouse over a clip and none in focus, '
      'Ctrl C copies its link and Ctrl Shift C its file', (tester) async {
    final items = await open(tester);
    await mouseOver(tester, 'Amber Skies');

    await press(tester, LogicalKeyboardKey.keyC, control: true);
    expect(links, [items[1].canonicalUrl]);

    await press(tester, LogicalKeyboardKey.keyC, control: true, shift: true);
    expect(files, [
      [items[1].localPath],
    ]);
  });

  testWidgets('one clip chosen by its mark is the one copied, wherever the '
      'mouse is', (tester) async {
    final items = await open(tester);
    await chooseByMark(tester, 'Night Drive');
    await mouseOver(tester, 'Low Tide');

    await press(tester, LogicalKeyboardKey.keyC, control: true, shift: true);
    expect(files, [
      [items[0].localPath],
    ]);
  });

  testWidgets('with several chosen nothing is copied, and it says one at a '
      'time', (tester) async {
    await open(tester);
    await chooseByMark(tester, 'Night Drive');
    await chooseByMark(tester, 'Amber Skies');

    await press(tester, LogicalKeyboardKey.keyC, control: true, shift: true);
    await press(tester, LogicalKeyboardKey.keyC, control: true);
    expect(files, isEmpty);
    expect(links, isEmpty);
    expect(find.text('Copying takes one clip at a time'), findsOneWidget);
    // Above the bar of what to do with the chosen ones, not over its last
    // buttons.
    final bar = find.ancestor(
      of: find.text('2 selected'),
      matching: find.byType(Material),
    );
    expect(
      tester.getRect(find.byType(MTNotice)).bottom,
      lessThanOrEqualTo(tester.getRect(bar.first).top),
    );
  });

  testWidgets('F and Enter under the mouse do nothing: only the copy keys '
      'follow the mouse', (tester) async {
    final items = await open(tester);
    await mouseOver(tester, 'Amber Skies');

    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.enter);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EmberSidebar)),
    );
    final tags = await container
        .read(tagsIndexProvider)
        .tagsOf(items[1].canonicalUrl);
    expect(tags, isNot(contains(MTConstants.favoritesSystemTag)));
    expect(find.text('Amber Skies'), findsOneWidget);
  });

  testWidgets('in a text field Ctrl C stays the field\'s own', (tester) async {
    await open(tester);
    await mouseOver(tester, 'Amber Skies');
    // The search, over the list, with the mouse still where it was.
    await press(tester, LogicalKeyboardKey.keyK, control: true);
    expect(find.byType(EditableText), findsWidgets);

    await press(tester, LogicalKeyboardKey.keyC, control: true);
    await press(tester, LogicalKeyboardKey.keyC, control: true, shift: true);
    expect(links, isEmpty);
    expect(files, isEmpty);
  });
}
