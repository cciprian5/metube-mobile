import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// **Debug builds only**: clears media_kit's hot-restart note left by a
/// dead process under this one's number.
///
/// In debug, media_kit keeps the address of a native buffer in a temp file
/// named after the process id, so a hot restart can free what the last run
/// held. A run that crashed or was killed leaves its file behind; when
/// Windows hands a later process the same id, that process reads an
/// address in memory that is not its own and crashes a few seconds in
/// (measured, often, on a machine that runs the tests). At the start of a
/// fresh process any such file is someone else's; after a hot restart in
/// the same process it is ours, so a mark in this process's environment,
/// which a hot restart keeps, tells the two apart.
void forgetStaleMediaKitNote() {
  if (!kDebugMode) return;
  const mark = 'EMBER_MEDIA_KIT_STARTED';
  if (Platform.environment.containsKey(mark)) return;
  final note = File(
    '${Directory.systemTemp.path}\\'
    'com.alexmercerind.media_kit.NativeReferenceHolder.$pid',
  );
  try {
    if (note.existsSync()) note.deleteSync();
  } on FileSystemException {
    // Unreadable or in use: media_kit will meet it as before.
  }
  final name = TEXT(mark);
  final value = TEXT('1');
  try {
    SetEnvironmentVariable(name, value);
  } finally {
    free(name);
    free(value);
  }
}
