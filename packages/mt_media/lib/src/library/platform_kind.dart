import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// Converts the core's platform into its presentation type, since mt_ui
/// does not know mt_core.
MTPlatformKind platformKindOf(MediaPlatform platform) => switch (platform) {
  MediaPlatform.youtube => MTPlatformKind.youtube,
  MediaPlatform.tiktok => MTPlatformKind.tiktok,
  MediaPlatform.instagram => MTPlatformKind.instagram,
  MediaPlatform.soundcloud => MTPlatformKind.soundcloud,
  MediaPlatform.x => MTPlatformKind.x,
  MediaPlatform.facebook => MTPlatformKind.facebook,
  MediaPlatform.vimeo => MTPlatformKind.vimeo,
  MediaPlatform.twitch => MTPlatformKind.twitch,
  MediaPlatform.reddit => MTPlatformKind.reddit,
  MediaPlatform.dailymotion => MTPlatformKind.dailymotion,
  MediaPlatform.other => MTPlatformKind.other,
};
