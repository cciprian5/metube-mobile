import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import '../../router.dart';
import '../../shell/video_surface.dart';

/// The video across the content and the side panel's columns. Kept for
/// the session only: it is a way of watching one clip, not a setting.
final theaterProvider = StateProvider<bool>((ref) => false);

/// The playing clip as sound alone: nothing decoded, the cover in place
/// of the picture.
final audioOnlyProvider = NotifierProvider<AudioOnlyNotifier, bool>(
  AudioOnlyNotifier.new,
);

class AudioOnlyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> set(bool on) async {
    if (on == state) return;
    state = on;
    await ref.read(videoSurfaceProvider).setAudioOnly(on);
  }
}

/// Plays [list] from [index], as a click in a list does, and opens the
/// clip's page when there is a picture to watch.
///
/// - **A short** plays in its lane: the portrait shorts of the same list,
///   in its order, each one looping until the user moves on.
/// - **Audio** plays in the player bar, and the list stays on screen.
/// - **A video** plays the list from there, on its own page.
Future<void> openFromList(
  WidgetRef ref,
  GoRouter router,
  List<PlaylistItem> list,
  int index,
) => playFromList(ref.read(playerProvider), router, list, index);

/// [openFromList] for a saved list, which names itself to the player so
/// its play mode is its own.
Future<void> playFromList(
  MTPlayer player,
  GoRouter router,
  List<PlaylistItem> list,
  int index, {
  String? playlistId,
  String? playlistName,
}) async {
  final item = list[index];
  if (item.isShortForm) {
    final lane = ShortsLane.from(list);
    await player.playItems(
      lane.items,
      startIndex: lane.laneIndexOf(item.canonicalUrl),
      playlistId: playlistId,
      playlistName: playlistName,
    );
    await player.setLooping(true);
  } else {
    await player.setLooping(false);
    await player.playItems(
      list,
      startIndex: index,
      playlistId: playlistId,
      playlistName: playlistName,
    );
  }
  if (!item.isAudio) router.go(EmberRoutes.item(item.canonicalUrl));
}
