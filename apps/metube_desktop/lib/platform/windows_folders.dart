import 'dart:io';

import 'package:file_selector/file_selector.dart' as selector;
import 'package:path_provider_windows/path_provider_windows.dart';

import '../data/folders_data.dart';

/// The Windows folders: the known Videos and Downloads (wherever OneDrive
/// or the user moved them), Windows' own folder dialog, and Explorer.
class WindowsFolders extends DesktopFolders {
  const WindowsFolders();

  static final _paths = PathProviderWindows();

  /// FOLDERID_Videos. The package names it too, but behind an import the
  /// analyzer resolves to a stub.
  static const _videos = '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}';

  @override
  Future<String?> videos() => _paths.getPath(_videos);

  @override
  Future<String?> downloads() => _paths.getDownloadsPath();

  @override
  Future<String?> pick({String? initial}) => selector.getDirectoryPath(
    initialDirectory: initial != null && Directory(initial).existsSync()
        ? initial
        : null,
    canCreateDirectories: true,
  );

  // Explorer is started with its arguments as a list, never through a
  // shell, so a name with spaces or an ampersand stays one argument.
  @override
  Future<void> reveal(String path) async {
    if (!File(path).existsSync()) return open(File(path).parent.path);
    await Process.start('explorer.exe', ['/select,', path]);
  }

  @override
  Future<void> open(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) await dir.create(recursive: true);
    await Process.start('explorer.exe', [dir.path]);
  }
}
