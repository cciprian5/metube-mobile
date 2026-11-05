import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

void main() {
  test("**the guard**: the phones' theme keeps its one-pixel rules and "
      'borders; only the desktop with high contrast thickens them', () {
    for (final variant in MTVariant.values) {
      for (final brightness in Brightness.values) {
        final phone = mtTheme(variant, brightness);
        expect(phone.extension<MTThemeX>()!.hairline, 1);
        expect(phone.dividerTheme.thickness, 1);
        final desk = mtDesktopTheme(variant, brightness);
        expect(desk.extension<MTThemeX>()!.hairline, 1);
        final contrast = mtDesktopTheme(
          variant,
          brightness,
          highContrast: true,
        );
        expect(contrast.extension<MTThemeX>()!.hairline, 2);
        expect(contrast.dividerTheme.thickness, 2);
      }
    }
  });
}
