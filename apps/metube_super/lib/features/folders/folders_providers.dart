import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_providers.dart';

/// The folders the server would save into, asked for when a picker opens
/// and forgotten when it closes, so a folder made on the server since then
/// shows the next time.
final serverFoldersProvider = FutureProvider.autoDispose<ServerFolders?>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  return api?.fetchFolders();
});

/// The folders the library's clips sit in.
final libraryFolderPathsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
  return {for (final item in items) ?item.folderPath};
});

/// Whether the server ignores the chosen folder ([foldersIgnored]).
final foldersIgnoredProvider = Provider<bool>(
  (ref) =>
      foldersIgnored(ref.watch(historyProvider).valueOrNull?.done ?? const []),
);
