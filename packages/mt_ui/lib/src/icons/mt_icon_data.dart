/// One Wahaj icon: an SVG with two colour slots, `{ink}` for the strokes
/// and `{ember}` for the single accent mark.
class MTIconData {
  const MTIconData(this.name, this.svg);

  /// The key in the source set, for tests and debugging.
  final String name;
  final String svg;

  /// The SVG with both slots filled.
  String paint({required String ink, required String ember}) =>
      svg.replaceAll('{ink}', ink).replaceAll('{ember}', ember);
}
