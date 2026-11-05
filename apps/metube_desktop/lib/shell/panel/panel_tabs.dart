import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// The side panel's three faces as one control: equal parts on a quiet
/// ground, and **a card under the chosen one that slides to the next**,
/// the same pace both ways. Three pills whose fill jumped from one to the
/// other said less about where the eye should go.
class PanelTabs<T> extends StatelessWidget {
  const PanelTabs({
    super.key,
    required this.faces,
    required this.chosen,
    required this.onChoose,
  });

  /// Each face and its name, in order.
  final List<(T, String)> faces;
  final T chosen;
  final ValueChanged<T> onChoose;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final index = faces.indexWhere((f) => f.$1 == chosen);
    final inner = BorderRadius.circular(
      MTCorners.desktop.chip - MTSpace.xxs / 2,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.xxs / 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: mtMotionDuration(context, MTMotion.page),
                curve: MTMotion.entrance,
                alignment: AlignmentDirectional(
                  faces.length < 2 ? 0 : -1 + 2 * index / (faces.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / faces.length,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: inner,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final (face, label) in faces)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: face == chosen,
                      child: InkWell(
                        borderRadius: inner,
                        onTap: () => onChoose(face),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: MTSpace.xs,
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.labelMedium?.copyWith(
                              color: face == chosen ? p.ink : p.ink2,
                              fontWeight: face == chosen
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
