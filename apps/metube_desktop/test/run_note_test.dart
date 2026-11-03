import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:metube_desktop/platform/run_note.dart';
import 'package:mt_core/mt_core.dart';

void main() {
  late Directory folder;
  late MTLogger logger;
  late RunNote note;

  Future<String> logged() async {
    final file = File(logger.filePath);
    return await file.exists() ? file.readAsString() : '';
  }

  File named(String name) => File('${folder.path}/$name');

  RunNote nextRun() => RunNote(folder: folder.path, logger: logger);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('run_note');
    logger = MTLogger(filePath: '${folder.path}/app.log');
    note = nextRun();
  });

  tearDown(() => folder.delete(recursive: true));

  test('the first run ever says nothing about a last one', () async {
    await note.begin();
    expect(await logged(), isEmpty);
    expect(await named(RunNote.openName).exists(), isTrue);
  });

  test('a run that closed by itself leaves nothing to report', () async {
    await note.begin();
    await note.end();
    expect(await named(RunNote.openName).exists(), isFalse);

    await nextRun().begin();
    final log = await logged();
    expect(log, contains('app closed'));
    expect(log, isNot(contains('without closing')));
  });

  test('**the guard**: a run that never closed is reported, so a stop is '
      'told from the user closing the window', () async {
    await note.begin();

    await nextRun().begin();
    expect(await logged(), contains('the last run ended without closing'));
  });

  test('**the guard**: the note from the runner reaches the log once, as a '
      'crash', () async {
    await note.begin();
    await named(
      RunNote.crashName,
    ).writeAsString('code 0xC0000005 in flutter_windows.dll at +0x3C18A\n');

    final next = nextRun();
    await next.begin();
    final log = await logged();
    expect(log, contains('[crash]'));
    expect(log, contains('code 0xC0000005 in flutter_windows.dll at +0x3C18A'));
    expect(log, isNot(contains('without closing')), reason: 'one report');
    expect(await named(RunNote.crashName).exists(), isFalse);

    await next.end();
    await nextRun().begin();
    expect('[crash]'.allMatches(await logged()), hasLength(1));
  });

  test('a note far too long for the runner is cut, not copied whole', () async {
    await named(RunNote.crashName).writeAsString('x' * 5000);
    await note.begin();
    expect((await logged()).length, lessThan(600));
  });

  test('a folder it cannot write to never stops the app', () async {
    final file = named('in_the_way');
    await file.writeAsString('');
    final blocked = RunNote(folder: file.path, logger: logger);
    await blocked.begin();
    await blocked.end();
  });
}
