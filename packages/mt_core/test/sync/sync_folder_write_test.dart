import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_write_');
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('**the guard**: a write waits out a sync program reading the file, '
      'instead of failing the sync', () async {
    final storage = IoSyncStorage(
      dir.path,
      renameRetries: const [
        Duration(milliseconds: 100),
        Duration(milliseconds: 200),
        Duration(milliseconds: 400),
      ],
    );
    await storage.write(['dev', 'library.json'], 'first');
    // The sync program has the file open for reading, as Syncthing does
    // while it hashes a file to send; Windows refuses to replace it.
    final reader = await File(storage.pathOf(['dev', 'library.json'])).open();
    final released = Future<void>.delayed(
      const Duration(milliseconds: 250),
      reader.close,
    );
    await storage.write(['dev', 'library.json'], 'second');
    await released;
    expect(await storage.read(['dev', 'library.json']), 'second');
  }, testOn: 'windows');

  test('a file that stays locked still fails, after the waits', () async {
    final storage = IoSyncStorage(
      dir.path,
      renameRetries: const [Duration(milliseconds: 10)],
    );
    await storage.write(['dev', 'library.json'], 'first');
    final reader = await File(storage.pathOf(['dev', 'library.json'])).open();
    addTearDown(reader.close);
    await expectLater(
      storage.write(['dev', 'library.json'], 'second'),
      throwsA(isA<FileSystemException>()),
    );
  }, testOn: 'windows');
}
