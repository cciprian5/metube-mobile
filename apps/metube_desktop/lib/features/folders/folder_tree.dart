import 'package:mt_media/library.dart';

/// One folder line in the sidebar.
typedef SidebarFolder = ({String path, int count, int depth});

/// The server folders the library's clips sit in, as the sidebar lists
/// them: the top level, and below the [open] folder (and each folder above
/// it) the folders inside, so the tree unfolds along the chosen path only.
/// Counts include what lies deeper; the rules of [folderCounts] apply, so
/// a level of one clip per folder is not offered.
List<SidebarFolder> sidebarFolders(List<LibraryItem> items, String? open) {
  List<SidebarFolder> level(String parent, int depth) => [
    for (final MapEntry(key: path, value: count) in folderCounts(
      items,
      parent: parent,
    )) ...[
      (path: path, count: count, depth: depth),
      if (open != null && (open == path || open.startsWith('$path/')))
        ...level(path, depth + 1),
    ],
  ];
  return level('', 0);
}

/// The folder above [path], or null at the top.
String? parentFolder(String path) {
  final cut = path.lastIndexOf('/');
  return cut < 0 ? null : path.substring(0, cut);
}
