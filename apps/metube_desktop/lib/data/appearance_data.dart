import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';

/// Day or night and the language, chosen in Appearance; per computer, as
/// the phone keeps its own.
typedef Appearance = ({ThemeMode theme, String? locale});

/// The languages on offer besides following Windows.
const appearanceLocales = ['ar', 'en'];

class AppearanceStore {
  AppearanceStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const themeKey = 'ember_theme';
  static const localeKey = 'ember_locale';

  /// Anything unknown follows Windows.
  Future<Appearance> read() async {
    final theme = switch (await store.getString(themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = await store.getString(localeKey);
    return (
      theme: theme,
      locale: appearanceLocales.contains(locale) ? locale : null,
    );
  }

  Future<void> writeTheme(ThemeMode theme) =>
      mutex.run(() => store.setString(themeKey, theme.name));

  Future<void> writeLocale(String? locale) => mutex.run(
    () => locale == null
        ? store.remove(localeKey)
        : store.setString(localeKey, locale),
  );
}

final appearanceStoreProvider = Provider(
  (ref) => AppearanceStore(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

/// Read in main before the first frame, so the app never opens in the
/// wrong colours or language and then changes.
final initialAppearanceProvider = Provider<Appearance>(
  (ref) => (theme: ThemeMode.system, locale: null),
);

final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => ref.watch(initialAppearanceProvider);

  void setTheme(ThemeMode theme) {
    state = (theme: theme, locale: state.locale);
    unawaited(ref.read(appearanceStoreProvider).writeTheme(theme));
  }

  /// Null follows Windows.
  void setLocale(String? locale) {
    state = (theme: state.theme, locale: locale);
    unawaited(ref.read(appearanceStoreProvider).writeLocale(locale));
  }
}
