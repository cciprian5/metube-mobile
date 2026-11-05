import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mt_ui/mt_ui.dart';

/// **The small marks the audit of 2026-10-30 found** (mobile plan): the
/// platform letters on every phone row, and words written in Title Case,
/// with exclamation marks and long dashes.
void main() {
  Widget host(Widget child, {bool desktop = false}) => MaterialApp(
    localizationsDelegates: MTLocalizations.localizationsDelegates,
    supportedLocales: MTLocalizations.supportedLocales,
    theme: mtTheme(MTVariant.superApp, Brightness.light),
    home: Scaffold(body: desktop ? MTDesktopApp(child: child) : child),
  );

  MTMediaCard card() => const MTMediaCard(
    title: 'Song',
    subtitle: 'Band',
    thumbnail: ColoredBox(color: Colors.teal),
    platform: MTPlatformKind.youtube,
  );

  testWidgets('**the guard**: a phone card carries no platform letters', (
    tester,
  ) async {
    await tester.pumpWidget(host(card()));
    expect(find.byType(MTPlatformChip), findsNothing);
  });

  testWidgets('the computer keeps them', (tester) async {
    await tester.pumpWidget(host(card(), desktop: true));
    expect(find.byType(MTPlatformChip), findsOneWidget);
  });

  Map<String, String> strings(String file) {
    final json = jsonDecode(
      File('lib/src/l10n/$file').readAsStringSync(),
    ) as Map<String, dynamic>;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (!key.startsWith('@') && value is String) key: value,
    };
  }

  test('**the guard**: no exclamation mark in either language', () {
    for (final file in ['app_en.arb', 'app_ar.arb']) {
      final loud = strings(file).entries.where((e) => e.value.contains('!'));
      expect(loud.map((e) => e.key), isEmpty, reason: file);
    }
  });

  test('**the guard**: no long dash in an English sentence', () {
    final dashed = strings('app_en.arb').entries.where(
      // The quote's attribution line is a format, not a sentence.
      (e) => e.value.contains(' — ') && e.key != 'desktopQuote',
    );
    expect(dashed.map((e) => e.key), isEmpty);
  });

  test('**the guard**: English labels are in sentence case', () {
    // Names and acronyms keep their capitals.
    const proper = {
      'MeTube',
      'Ember',
      'Super',
      'Lite',
      'Windows',
      'Explorer',
      'Markdown',
      'PDF',
      'SRT',
      'URL',
      'Wi-Fi',
      'Yasir',
      'Sagheer',
      'YouTube',
      'A',
      'Z',
      'I',
      'Settings',
      'Server',
    };
    final shouting = <String>[];
    strings('app_en.arb').forEach((key, value) {
      final words = RegExp(r"[A-Za-z][A-Za-z'-]*").allMatches(value).toList();
      // Labels only: a sentence starts new ones after a full stop, and a
      // plural message holds several in one value.
      if (words.length < 2 || words.length > 6) return;
      if (value.contains(RegExp(r'[.:·{]'))) return;
      final rest = words.skip(1).map((m) => m.group(0)!);
      final capitals = rest.where(
        (w) => w[0] == w[0].toUpperCase() && !proper.contains(w),
      );
      if (capitals.length >= 2) shouting.add('$key: $value');
    });
    expect(shouting, isEmpty);
  });
}
