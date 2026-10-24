import '../models/history_item.dart';
import '../models/server_folders.dart';
import '../urls/server_path.dart';

/// A folder chosen in a picker. An empty [path] is the top of the
/// downloads, unless [channelName] says "named after the channel", which
/// only the server can resolve.
class FolderChoice {
  const FolderChoice(this.path, {this.channelName = false});

  static const top = FolderChoice('');
  static const channel = FolderChoice('', channelName: true);

  final String path;
  final bool channelName;

  bool get isTop => path.isEmpty && !channelName;
}

/// **Every folder a picker can offer**, for video or for audio: what the
/// server lists, and the folders the library's clips sit in, with each
/// one's parents, so a server that does not list its folders still offers
/// the ones in use. In tree order, a parent before what is inside it.
List<String> pickableFolders(
  ServerFolders? server,
  Iterable<String> fromLibrary, {
  required bool audio,
}) {
  final all = <String>{};
  void add(String path) {
    final parts = ServerPath.cleanFolder(path).split('/');
    for (var i = 1; i <= parts.length; i++) {
      final prefix = parts.take(i).join('/');
      if (prefix.isNotEmpty) all.add(prefix);
    }
  }

  for (final path in server?.of(audio: audio) ?? const <String>[]) {
    add(path);
  }
  fromLibrary.forEach(add);
  int byTree(String a, String b) {
    final x = a.toLowerCase().split('/');
    final y = b.toLowerCase().split('/');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final c = x[i].compareTo(y[i]);
      if (c != 0) return c;
    }
    return x.length.compareTo(y.length);
  }

  return all.toList()..sort(byTree);
}

/// **True when the server ignores the chosen folder** and saves at the
/// top: an absolute `outtmpl` in its `YTDL_OPTIONS` overrides the folder,
/// and MeTube then reports the file as `Folder/../name`. A picker says so
/// rather than let a choice look as if it worked.
///
/// **Only the newest download into a folder counts**: older ones, made
/// before the server's settings were corrected, stay in the history as
/// they were and must not keep the warning up once folders work.
bool foldersIgnored(Iterable<HistoryItem> done) {
  HistoryItem? newest;
  for (final item in done) {
    if (!(item.folder?.isNotEmpty ?? false)) continue;
    final at = item.timestamp;
    if (newest == null ||
        (at != null && at.isAfter(newest.timestamp ?? DateTime(0)))) {
      newest = item;
    }
  }
  return newest?.filename?.startsWith('../') ?? false;
}

/// **A folder named after a channel**: the name is one folder, so a slash
/// in it ("AC/DC") is not read as nesting.
String channelFolderName(String name) =>
    ServerPath.cleanFolder(name.replaceAll(RegExp(r'[/\\]'), '-'));
