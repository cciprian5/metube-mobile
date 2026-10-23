import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// The Wahaj switch: a hairline track whose knob is an empty ring when off
/// and **the ember itself** when on, glowing in the accent. The only
/// coloured thing on a settings page is the setting that is on.
///
/// Space or Enter toggles it from the keyboard, and the focus ring shows
/// only when the keyboard put the focus there.
class MTSwitch extends StatefulWidget {
  const MTSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<MTSwitch> createState() => _MTSwitchState();
}

class _MTSwitchState extends State<MTSwitch> {
  static const _width = 40.0;
  static const _height = 22.0;
  static const _knob = 13.0;
  static const _inset = 3.0;
  bool _focusRing = false;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final on = widget.value;
    final enabled = widget.onChanged != null;
    return Semantics(
      toggled: on,
      enabled: enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _focusRing = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _toggle(),
          ),
        },
        child: GestureDetector(
          onTap: enabled ? _toggle : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: MTMotion.fast,
              curve: MTMotion.ease,
              width: _width,
              height: _height,
              padding: const EdgeInsets.all(_inset),
              decoration: BoxDecoration(
                color: on ? p.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: on ? p.accent : p.line2, width: 1.5),
                boxShadow: _focusRing
                    ? [BoxShadow(color: p.accent, spreadRadius: 2)]
                    : null,
              ),
              child: AnimatedAlign(
                duration: MTMotion.fast,
                curve: MTMotion.ease,
                alignment: on
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: AnimatedContainer(
                  duration: MTMotion.fast,
                  width: _knob,
                  height: _knob,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? p.accent : Colors.transparent,
                    border: Border.all(
                      color: on ? p.accent : p.ink3,
                      width: 1.6,
                    ),
                    boxShadow: on
                        ? [
                            BoxShadow(
                              color: p.accent.withValues(alpha: 0.22),
                              spreadRadius: 3,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
