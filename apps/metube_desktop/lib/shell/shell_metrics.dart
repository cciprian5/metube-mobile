import 'shell_layout.dart';

/// The fixed measures of the Windows shell, in logical pixels.
abstract final class EmberShellSize {
  static const double titleBar = 40;

  /// One caption button, the width Windows itself gives them.
  static const double captionButton = 46;

  static const double sidebarWide = 240;

  /// Icons only, wide enough for the add button's square.
  static const double sidebarNarrow = 72;

  static const double panel = 340;

  /// Fixed: the player never moves or hides while the user navigates.
  static const double playerBar = 88;

  /// From this width the three columns sit side by side.
  static const double threeColumns = 1280;

  /// Below this the panel no longer fits beside the content and slides
  /// over it instead.
  static const double panelBeside = 1100;

  /// A small dialog: a list to tick, a field.
  static const double smallDialog = 360;

  /// A dialog of several fields: following a channel.
  static const double formDialog = 440;

  /// Adding one link: the link, its preview and the choices.
  static const double addDialog = 560;

  /// A dialog of many lines: several links, a playlist's clips.
  static const double wideDialog = 720;

  /// A list's card: a cover a little smaller than the library's widest
  /// cell, so the cards wrap like a shelf.
  static const double listCard = 200;

  /// The widest a clip's picture grows, so a maximized 2560 window does
  /// not stretch a 1080p picture past its own pixels.
  static const double clipMax = 1280;

  /// The picture in the reading room's corner: small beside the article,
  /// still large enough to follow who is speaking.
  static const double readingVideo = 300;
}

/// How the columns share a given window width.
class ShellArrangement {
  const ShellArrangement({
    required this.sidebarWidth,
    required this.panelBeside,
    required this.canWidenSidebar,
  });

  final double sidebarWidth;

  /// The panel is a column beside the content; otherwise it is a layer
  /// that slides over the content when asked for.
  final bool panelBeside;

  /// Only a window of three full columns lets the user choose a wide
  /// sidebar; narrower ones force it to icons.
  final bool canWidenSidebar;

  bool get sidebarNarrow => sidebarWidth == EmberShellSize.sidebarNarrow;
}

/// The column rules: at 1280 and wider everything is as the user left it;
/// from 1100 the sidebar narrows to icons by itself so the panel can stay;
/// below 1100 the panel becomes a layer. The user's choices are kept and
/// come back when the window grows again.
ShellArrangement arrangeShell(double width, ShellLayout layout) {
  final roomy = width >= EmberShellSize.threeColumns;
  return ShellArrangement(
    sidebarWidth: roomy && !layout.sidebarNarrow
        ? EmberShellSize.sidebarWide
        : EmberShellSize.sidebarNarrow,
    panelBeside: width >= EmberShellSize.panelBeside,
    canWidenSidebar: roomy,
  );
}
