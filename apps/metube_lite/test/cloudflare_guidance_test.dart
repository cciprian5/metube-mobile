import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_page.dart';
import 'package:metube_lite/features/settings/settings_sections.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:metube_lite/features/settings/widgets/help_button.dart';
import 'package:metube_lite/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// What the person is told about Cloudflare Access (feature 001, FR-012 to
/// FR-014 and SC-005).
///
/// Two defects are guarded: guidance that exists in the file but never
/// reaches the screen (the helper line, the help dialog), and a rejection
/// message that sends the person to the wrong field, such as one that talks
/// about the server password or the address when the token is what failed.
void main() {
  late ProviderContainer container;
  late MemorySecretStore secrets;

  Widget host({String language = 'en'}) {
    secrets = MemorySecretStore();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(secrets),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const LiteSettings()),
      ],
    );
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(language),
        localizationsDelegates: MTLocalizations.localizationsDelegates,
        supportedLocales: MTLocalizations.supportedLocales,
        theme: mtTheme(MTVariant.lite, Brightness.light),
        home: const SettingsPage(SettingsPane.server),
      ),
    );
  }

  for (final language in ['en', 'ar']) {
    testWidgets('the helper line and the help dialog render ($language)', (
      tester,
    ) async {
      await tester.pumpWidget(host(language: language));
      await tester.pumpAndSettle();
      final l10n = MTLocalizations.of(
        tester.element(find.byType(SettingsPage)),
      );

      // Said in the open, as the credentials' own helper is.
      expect(find.text(l10n.cloudflareHelper), findsOneWidget);

      final help = find.byWidgetPredicate(
        (w) => w is HelpButton && w.title == l10n.cloudflareHelpTitle,
      );
      expect(help, findsOneWidget);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.text(l10n.cloudflareHelpBody), findsOneWidget);
    });
  }

  testWidgets('the secret alone is refused, nothing stored, nothing sent', (
    tester,
  ) async {
    // The other half of "both or neither": the fields test fills the ID.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final l10n = MTLocalizations.of(tester.element(find.byType(SettingsPage)));

    await tester.enterText(
      find.widgetWithText(TextField, l10n.serverUrl),
      'https://metube.example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.cloudflareClientSecret),
      's3cr3t',
    );
    await tester.ensureVisible(find.text(l10n.saveSettings));
    await tester.tap(find.text(l10n.saveSettings));
    await tester.pump();

    expect(find.text(l10n.cloudflareBothRequired), findsOneWidget);
    // The button is still usable: the test never started.
    expect(find.text(l10n.testingConnection), findsNothing);
    expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);
    expect(container.read(settingsProvider).serverUrl, isEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('the whole form fits with the guidance at every size', (
    tester,
  ) async {
    await expectNoOverflow(tester, host);
  });

  group('errorText', () {
    late MTLocalizations en;
    late MTLocalizations ar;

    setUpAll(() async {
      en = await MTLocalizations.delegate.load(const Locale('en'));
      ar = await MTLocalizations.delegate.load(const Locale('ar'));
    });

    test('a rejected token gets its own message', () {
      expect(
        errorText(en, const AccessRejectedException()),
        en.errAccessRejected,
      );
      expect(
        errorText(ar, const AccessRejectedException()),
        ar.errAccessRejected,
      );
    });

    test('the other exceptions keep the text they had', () {
      expect(errorText(en, const AuthFailureException()), en.errAuth);
      expect(errorText(en, const NetworkException()), en.errNetwork);
      expect(errorText(en, const NotMeTubeServerException()), en.errNotMeTube);
    });

    test('the message names the token and not the password or address', () {
      // SC-005: it must send the person to the Cloudflare fields, not to the
      // server's own password or to the address.
      final english = en.errAccessRejected.toLowerCase();
      expect(english, contains('client id'));
      expect(english, contains('client secret'));
      expect(english, isNot(contains('password')));
      expect(english, isNot(contains('address')));

      final arabic = ar.errAccessRejected;
      expect(arabic, contains('معرّف العميل'));
      expect(arabic, contains('سرّ العميل'));
      expect(arabic, isNot(contains('كلمة المرور')));
      expect(arabic, isNot(contains('عنوان')));
    });
  });
}
