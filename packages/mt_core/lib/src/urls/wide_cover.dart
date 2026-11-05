import 'url_kit.dart';

/// The wide YouTube picture for a square cover, where [cover] is what the
/// clip shows and [canonicalUrl] is the clip.
///
/// The address of `hqdefault` gives it directly ([UrlKit.youtubeWideThumbnail]).
/// A cover kept on this device is a file, and its name says nothing, so
/// the clip's own address gives the number instead: without this, a kept
/// cover brought the black bands back to the lock screen and the audio
/// player. Null for anything that is not YouTube.
String? youtubeWideCover(String? cover, String? canonicalUrl) {
  final fromCover = UrlKit.youtubeWideThumbnail(cover);
  if (fromCover != null) return fromCover;
  if (cover == null || cover.startsWith('http') || canonicalUrl == null) {
    return null;
  }
  final id = UrlKit.youtubeVideoId(canonicalUrl);
  return id == null ? null : 'https://i.ytimg.com/vi/$id/maxresdefault.jpg';
}
