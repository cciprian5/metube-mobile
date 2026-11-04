import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';

import 'local_copies.dart';

/// Puts files on the clipboard as files; overridden in main with
/// Windows' own, false (nothing copied) in tests that do not say.
final filesToClipboardProvider = Provider<bool Function(List<String> paths)>(
  (ref) =>
      (_) => false,
);

/// The bytes free on the drive of a folder; null when unknown, which never
/// stops a copy.
final freeBytesProvider = Provider<int? Function(String folder)>(
  (ref) =>
      (_) => null,
);

/// What copying a clip's file takes.
sealed class FileCopyPlan {
  const FileCopyPlan();
}

/// The file is already on this computer: it goes on the clipboard now.
final class CopyNow extends FileCopyPlan {
  const CopyNow(this.path);
  final String path;
}

/// Only the server has it: it is saved into [folder] first, as a download
/// of the user's own, and copied once it is there. [large] asks first.
final class PullFirst extends FileCopyPlan {
  const PullFirst(this.source, this.folder, {required this.large});
  final CopySource source;
  final String folder;
  final bool large;
}

/// The drive cannot hold it; said before a byte is pulled.
final class NoSpace extends FileCopyPlan {
  const NoSpace({required this.needed, required this.free});
  final int needed;
  final int free;
}

/// Neither this computer nor the server has a file to give.
final class NothingToCopy extends FileCopyPlan {
  const NothingToCopy();
}

/// Above this a copy asks first: it means minutes of pulling, and most
/// chat apps refuse a file this big anyway.
const largeCopyBytes = 2 * 1024 * 1024 * 1024;

/// Room kept free beyond the file itself, so a copy never fills a drive.
const _spareBytes = 512 * 1024 * 1024;

/// Decides how [item] is copied. [localFile] is its copy on this computer,
/// if any; [lengthOf] reads a file's length, null when it is not there.
///
/// **A file already pulled into [folder] is copied again, not pulled
/// again**: the same name with the server's own size is the same clip, so
/// copying a clip twice never leaves a "(2)" beside it.
FileCopyPlan planFileCopy(
  LibraryItem item, {
  required String? localFile,
  required String? folder,
  required int? Function(String path) lengthOf,
  required int? freeBytes,
}) {
  if (localFile != null) return CopyNow(localFile);
  final source = copySourceOf(item);
  if (source == null || folder == null) return const NothingToCopy();
  final size = item.sizeBytes;
  final name = windowsSafeName(ServerPath.basename(source.serverPath));
  final already = '$folder\\$name';
  if (size != null && size > 0 && lengthOf(already) == size) {
    return CopyNow(already);
  }
  if (size != null && freeBytes != null && freeBytes < size + _spareBytes) {
    return NoSpace(needed: size, free: freeBytes);
  }
  return PullFirst(
    source,
    folder,
    large: size != null && size > largeCopyBytes,
  );
}

/// A file's length, or null when there is no such file.
int? fileLength(String path) {
  final file = File(path);
  return file.existsSync() ? file.lengthSync() : null;
}

/// The copy of [canonicalUrl] already being pulled into [folder], if one
/// is: asking twice waits on it instead of pulling the file twice.
LocalCopy? pullUnderWay(
  List<LocalCopy> copies,
  String canonicalUrl,
  String folder,
) => copies
    .where(
      (c) =>
          c.isActive &&
          c.kind == CopyKind.download &&
          c.canonicalUrl == canonicalUrl &&
          c.folder == folder,
    )
    .lastOrNull;
