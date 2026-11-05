import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';

/// Where each view of the library was left, for this session only.
///
/// Every place in the window is opened with `go`, which replaces the page:
/// a clip opened from far down the list, then Back or Library, rebuilt the
/// library at its top, and the user had to scroll down again to the next
/// clip. The phones keep their place because the player is pushed over the
/// library; here the offset is kept instead and given back.
final libraryOffsetsProvider = Provider<Map<String, double>>((ref) => {});

/// One view of the library: its place, filters, sort and layout. Another
/// view is another list, so it keeps its own offset and a new one starts at
/// the top, as before.
String libraryPlaceKey(LibraryScope scope, LibraryViewOptions options) => [
  scope.name,
  options.type.name,
  options.platform?.name ?? '',
  options.channel ?? '',
  options.query,
  options.folder ?? '',
  [...options.tags]..sort(),
  [...options.excludedTags]..sort(),
  options.sort.name,
  options.mode.name,
].join('|');

/// Builds the library's scroll view with a controller that starts where
/// [place] was left and keeps track of it.
class LibraryScroll extends ConsumerStatefulWidget {
  const LibraryScroll({super.key, required this.place, required this.builder});

  final String place;
  final Widget Function(ScrollController controller) builder;

  @override
  ConsumerState<LibraryScroll> createState() => _LibraryScrollState();
}

class _LibraryScrollState extends ConsumerState<LibraryScroll> {
  late final Map<String, double> _offsets = ref.read(libraryOffsetsProvider);
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsets[widget.place] ?? 0,
  )..addListener(_keep);

  // A filter changed here moves the list as it always did; from then on
  // the offset is kept for the new view.
  void _keep() {
    if (_controller.hasClients) _offsets[widget.place] = _controller.offset;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_keep)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
