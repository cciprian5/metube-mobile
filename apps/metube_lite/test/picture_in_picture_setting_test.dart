import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:metube_lite/features/settings/widgets/settings_fields.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show MTPictureInPicture;
import 'package:mt_ui/mt_ui.dart';

/// **Guard: picture in picture is off until turned on** (mobile plan,
/// stage 16/F). Its switch in the playback settings is kept, and the
/// player hears of it.
void main() {
  tearDown(MTPictureInPicture.instance.reset);

  testWidgets('**the guard**: off at first; the switch turns it on and '
      'keeps it', (tester) async {
    final store = MemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          await tester.runAsync(
                () => LiteSettings.load(store, MemorySecretStore()),
              ) ??
              const LiteSettings(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('en'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: const Scaffold(body: PlaybackFields()),
        ),
      ),
    );
    expect(container.read(settingsProvider).pictureInPicture, isFalse);
    expect(MTPictureInPicture.instance.enabled.value, isFalse);
    await tester.tap(find.text('Picture in picture'));
    await tester.pumpAndSettle();
    expect(MTPictureInPicture.instance.enabled.value, isTrue);
    expect(await store.getBool('picture_in_picture'), isTrue);
  });
}
