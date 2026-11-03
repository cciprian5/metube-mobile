import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_hub.dart';
import 'package:metube_super/features/settings/settings_page.dart';
import 'package:metube_super/features/settings/settings_screen.dart';
import 'package:metube_super/features/settings/settings_sections.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/server_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// The Cloudflare Access group in the server form (feature 001, FR-001 and
/// FR-014).
///
/// Two defects are guarded: a group that is not on the screen at all, so the
/// feature cannot be reached, and a group that costs the form its fit on a
/// small phone at a large font (the form grew by two fields and a title).
void main() {
  late ProviderContainer container;
  late MemorySecretStore secrets;

  ProviderContainer makeContainer(SuperSettings settings) {
    secrets = MemorySecretStore();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(secrets),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(settings),
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_cf_fields.log'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget host({
    String language = 'en',
    Brightness brightness = Brightness.light,
    SuperSettings settings = const SuperSettings(),
  }) => UncontrolledProviderScope(
    container: makeContainer(settings),
    child: MaterialApp(
      locale: Locale(language),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, brightness),
      home: const SettingsPage(SettingsPane.server),
    ),
  );

  final stored = SuperSettings(
    activeUrl: 'https://metube.example.com',
    cloudflareAccess: CloudflareAccess(
      clientId: 'id.access',
      clientSecret: 's3cr3t',
    ),
  );

  for (final language in ['en', 'ar']) {
    testWidgets('the group and its labels are on the screen ($language)', (
      tester,
    ) async {
      await tester.pumpWidget(host(language: language));
      await tester.pumpAndSettle();
      final l10n = MTLocalizations.of(
        tester.element(find.byType(SettingsPage)),
      );
      for (final text in [
        l10n.cloudflareAccess,
        l10n.cloudflareClientId,
        l10n.cloudflareClientSecret,
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });
  }

  testWidgets('the secret is masked until it is revealed', (tester) async {
    // Defect: a secret readable over the shoulder on every visit.
    await tester.pumpWidget(host(settings: stored));
    await tester.pumpAndSettle();
    final l10n = MTLocalizations.of(tester.element(find.byType(SettingsPage)));

    TextField secretField() => tester.widget<TextField>(
      find.widgetWithText(TextField, l10n.cloudflareClientSecret),
    );
    expect(secretField().obscureText, isTrue);
    // The stored values come back into the form.
    expect(find.text('id.access'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip(l10n.cloudflareShowSecret));
    await tester.tap(find.byTooltip(l10n.cloudflareShowSecret));
    await tester.pump();
    expect(secretField().obscureText, isFalse);
    expect(find.byTooltip(l10n.cloudflareHideSecret), findsOneWidget);
  });

  testWidgets('one value alone is refused and nothing is stored', (
    tester,
  ) async {
    // Defect (contract rule 2): half a pair earns a rejection that looks
    // like a wrong address.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final l10n = MTLocalizations.of(tester.element(find.byType(SettingsPage)));

    await tester.enterText(
      find.widgetWithText(TextField, l10n.serverUrl),
      'https://metube.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.cloudflareClientId),
      'id.access',
    );
    await tester.ensureVisible(find.text(l10n.saveSettings));
    await tester.tap(find.text(l10n.saveSettings));
    await tester.pump();

    expect(find.text(l10n.cloudflareBothRequired), findsOneWidget);
    expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
    expect(container.read(settingsProvider).activeUrl, isNull);
    // Let the snack bar's timer finish.
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('the tablet server pane carries the same group', (tester) async {
    // The pane reuses `ServerFields`; this is the shape a tablet held
    // sideways takes.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: makeContainer(const SuperSettings()),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          theme: mtTheme(MTVariant.superApp, Brightness.light),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsHub), findsOneWidget);
    expect(find.byType(ServerFields), findsOneWidget);
    final l10n = tester.element(find.byType(SettingsScreen)).mtl;
    expect(find.text(l10n.cloudflareClientId), findsWidgets);
    expect(find.text(l10n.cloudflareClientSecret), findsWidgets);
  });

  for (final language in ['en', 'ar']) {
    for (final brightness in Brightness.values) {
      testWidgets('**device matrix**: the group overflows nothing '
          '($language, ${brightness.name})', (tester) async {
        await expectNoOverflow(
          tester,
          () => host(
            language: language,
            brightness: brightness,
            settings: stored,
          ),
        );
      });
    }
  }

  testWidgets(
    'the toggle is named for screen readers and the secret is masked again on reopening',
    (tester) async {
      // Defect: an icon with no name is "button" to TalkBack, and a revealed
      // secret that stayed revealed on the next visit.
      await tester.pumpWidget(host(settings: stored));
      await tester.pumpAndSettle();
      final l10n = MTLocalizations.of(
        tester.element(find.byType(SettingsPage)),
      );

      final handle = tester.ensureSemantics();
      // What a screen reader announces for the icon button.
      String toggleName() => tester
          .getSemantics(
            find.descendant(
              of: find.byType(InputDecorator).last,
              matching: find.byType(IconButton),
            ),
          )
          .getSemanticsData()
          .tooltip;
      await tester.ensureVisible(find.byTooltip(l10n.cloudflareShowSecret));
      // The semantics tree is built on the frame after it is enabled.
      await tester.pump();
      expect(toggleName(), l10n.cloudflareShowSecret);
      await tester.tap(find.byTooltip(l10n.cloudflareShowSecret));
      await tester.pump();
      expect(toggleName(), l10n.cloudflareHideSecret);
      handle.dispose();

      // Leave the screen and come back.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(settings: stored));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, l10n.cloudflareClientSecret),
      );
      expect(field.obscureText, isTrue);
    },
  );
}
