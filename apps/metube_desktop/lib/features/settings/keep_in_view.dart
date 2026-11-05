import 'package:flutter/widgets.dart';

/// A scrolling list of entries, scrolled so the chosen one is in view.
///
/// **Whenever the list or the window changes size**, not only once: the
/// window opens at one size and takes its saved one a moment later, and
/// values under the entries (a count, a version) arrive after the first
/// frame and push the lower entries down; revealed once, the chosen entry
/// ended just out of view. The list is built whole, so an entry below the
/// fold exists to be revealed.
class KeepChosenInView extends StatefulWidget {
  const KeepChosenInView({
    super.key,
    required this.chosen,
    required this.isChosen,
    required this.padding,
    required this.child,
  });

  /// What is chosen; a change brings the new one into view.
  final Object chosen;

  /// Whether a widget in [child] is the chosen entry.
  final bool Function(Widget widget) isChosen;

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  State<KeepChosenInView> createState() => _KeepChosenInViewState();
}

class _KeepChosenInViewState extends State<KeepChosenInView> {
  Size? _window;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final window = MediaQuery.sizeOf(context);
    if (window == _window) return;
    _window = window;
    _reveal();
  }

  @override
  void didUpdateWidget(KeepChosenInView old) {
    super.didUpdateWidget(old);
    if (old.chosen != widget.chosen) _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final entry = _find(context as Element);
    // Not yet laid out (a page still arriving): its own change of size
    // brings another turn.
    final box = entry?.findRenderObject();
    if (entry == null || box is! RenderBox || !box.hasSize) return;
    Scrollable.ensureVisible(
      entry,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });

  Element? _find(Element list) {
    Element? found;
    void look(Element e) {
      if (found != null) return;
      if (widget.isChosen(e.widget)) {
        found = e;
        return;
      }
      e.visitChildren(look);
    }

    list.visitChildren(look);
    return found;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _reveal();
          return true;
        },
        child: SingleChildScrollView(
          padding: widget.padding,
          child: SizeChangedLayoutNotifier(child: widget.child),
        ),
      );
}
