import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Puts files on Windows' clipboard **as files**, the way Explorer's Copy
/// does: only their paths go there (`CF_HDROP`), never their bytes, so a
/// clip of several gigabytes costs the clipboard a few hundred bytes. Chat
/// apps, mail and Explorer then paste the files themselves.
///
/// "Preferred DropEffect" says copy: without it Explorer may treat the
/// paste as a move and take the file out of the download folder.
bool putFilesOnClipboard(List<String> paths) {
  if (paths.isEmpty) return false;
  final text = '${paths.join('\u0000')}\u0000\u0000';
  final size = _dropFilesHeader + text.length * 2;
  if (OpenClipboard(NULL) == FALSE) return false;
  try {
    EmptyClipboard();
    final files = GlobalAlloc(GMEM_MOVEABLE, size);
    if (files == nullptr) return false;
    final bytes = GlobalLock(files).cast<Uint8>();
    final header = bytes.cast<Uint32>();
    // DROPFILES: where the names start, a drop point and its flag, unused
    // here, then fWide, since the names are UTF-16.
    header[0] = _dropFilesHeader;
    header[1] = 0;
    header[2] = 0;
    header[3] = 0;
    header[4] = TRUE;
    final names = (bytes + _dropFilesHeader).cast<Uint16>();
    for (var i = 0; i < text.length; i++) {
      names[i] = text.codeUnitAt(i);
    }
    GlobalUnlock(files);
    if (SetClipboardData(CF_HDROP, files.address) == NULL) {
      _globalFree(files.address);
      return false;
    }
    _preferCopy();
    return true;
  } finally {
    CloseClipboard();
  }
}

void _preferCopy() {
  final name = 'Preferred DropEffect'.toNativeUtf16();
  try {
    final format = RegisterClipboardFormat(name);
    if (format == 0) return;
    final effect = GlobalAlloc(GMEM_MOVEABLE, 4);
    if (effect == nullptr) return;
    GlobalLock(effect).cast<Uint32>().value = _dropEffectCopy;
    GlobalUnlock(effect);
    if (SetClipboardData(format, effect.address) == NULL) {
      _globalFree(effect.address);
    }
  } finally {
    calloc.free(name);
  }
}

/// Bytes free to this user on the drive that holds [folder]; null when
/// Windows cannot say.
int? freeBytesAt(String folder) {
  final path = folder.toNativeUtf16();
  final free = calloc<Uint64>();
  try {
    return GetDiskFreeSpaceEx(path, free, nullptr, nullptr) == FALSE
        ? null
        : free.value;
  } finally {
    calloc
      ..free(path)
      ..free(free);
  }
}

/// DROPFILES is five 32-bit fields.
const _dropFilesHeader = 20;
const _dropEffectCopy = 1;

final _globalFree = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GlobalFree');
