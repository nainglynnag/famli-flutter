import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  final SecureStorage _storage = SecureStorage();

  @override
  ThemeMode build() {
    _hydrate();
    return ThemeMode.light;
  }

  Future<void> _hydrate() async {
    final stored = await _storage.read(Env.themeModeStorageKey);
    if (stored == 'dark') {
      state = ThemeMode.dark;
    } else if (stored == 'light') {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await _storage.write(Env.themeModeStorageKey, value);
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
