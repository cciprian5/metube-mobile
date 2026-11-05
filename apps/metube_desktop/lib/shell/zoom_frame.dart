import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'ui_zoom.dart';

/// The interface size, applied to everything: the app is laid out on a
/// smaller (or larger) logical canvas and scaled back to the window.
///
/// **Above the navigator** (from `MaterialApp.builder`), so dialogs, menus
/// and tooltips grow with the pages. Text stays sharp because the pixel
/// ratio is scaled with it, as measured on Windows at 100% and 150%.
///
/// Also owns Ctrl+= / Ctrl+- / Ctrl+0, as in a browser, says once when
/// Ember had to choose a smaller size for this screen, and draws the
/// keyboard focus ring over everything.
class EmberZoomFrame extends ConsumerStatefulWidget {
  const EmberZoomFrame({
    super.key,
    required this.child,
    required this.onChangeZoom,
  });

  final Widget child;

  /// Opens the setting, from the notice's button.
  final VoidCallback onChangeZoom;

  @override
  ConsumerState<EmberZoomFrame> createState() => _EmberZoomFrameState();
}

class _EmberZoomFrameState extends ConsumerState<EmberZoomFrame> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    ref.listenManual(uiZoomProvider, (_, next) {
      // After the frame: the notice needs the shell's Scaffold.
      if (next.lowered) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sayLowered());
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  void _sayLowered() {
    final zoom = ref.read(uiZoomProvider);
    if (!mounted || !zoom.lowered) return;
    final l = context.mtl;
    showMTNotice(
      context,
      message: l.desktopZoomLowered(zoom.percent),
      actionLabel: l.desktopZoomChange,
      onAction: widget.onChangeZoom,
    );
    ref.read(uiZoomProvider.notifier).acknowledge();
  }

  /// By the key's place, not its character, so the shortcuts work on an
  /// Arabic keyboard too.
  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent || !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    final zoom = ref.read(uiZoomProvider.notifier);
    switch (event.physicalKey) {
      case PhysicalKeyboardKey.equal || PhysicalKeyboardKey.numpadAdd:
        zoom.zoomIn();
      case PhysicalKeyboardKey.minus || PhysicalKeyboardKey.numpadSubtract:
        zoom.zoomOut();
      case PhysicalKeyboardKey.digit0 || PhysicalKeyboardKey.numpad0:
        zoom.reset();
      default:
        return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(uiZoomProvider).value;
    // The focus ring sits outside the zoom: focus reports where a control
    // is in the window's own coordinates.
    return MTFocusRingLayer(child: _zoomed(context, scale));
  }

  Widget _zoomed(BuildContext context, double scale) {
    // The app keeps its state across this switch: the router's navigator
    // has a global key, so it moves rather than starting over.
    if (scale == 1.0) return widget.child;
    final mq = MediaQuery.of(context);
    final logical = mq.size / scale;
    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        devicePixelRatio: mq.devicePixelRatio * scale,
        padding: mq.padding / scale,
        viewPadding: mq.viewPadding / scale,
        viewInsets: mq.viewInsets / scale,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
