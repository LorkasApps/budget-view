import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/preference_store.dart';
import '../core/preferences/preference_store_provider.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

/// The app's theme-mode choice, kept in the device-local [PreferenceStore].
class ThemeModeController extends Notifier<ThemeMode> {
  static const preferenceKey = 'theme_mode';

  @override
  ThemeMode build() {
    final stored = ref.read(preferenceStoreProvider).getString(preferenceKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref.read(preferenceStoreProvider).setString(preferenceKey, mode.name);
  }
}
