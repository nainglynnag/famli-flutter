import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  final SecureStorage _storage = SecureStorage();

  @override
  ThemeMode build() {
    _hydrate();
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      final prevMode = previous?.value?.profile?.preferences?.themeMode;
      final nextMode = next.value?.profile?.preferences?.themeMode;
      if (nextMode != null && nextMode != prevMode) {
        syncFromAccount(nextMode);
      }
    });
    return ThemeMode.light;
  }

  Future<void> _hydrate() async {
    final stored = await _storage.read(Env.themeModeStorageKey);
    if (stored == 'dark') {
      state = ThemeMode.dark;
      return;
    } else if (stored == 'light') {
      state = ThemeMode.light;
      return;
    }
    final accountMode = ref.read(authProvider).value?.profile?.preferences?.themeMode;
    if (accountMode != null) {
      syncFromAccount(accountMode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode, {bool syncToAccount = true}) async {
    state = mode;
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await _storage.write(Env.themeModeStorageKey, value);

    if (syncToAccount) {
      final token = ref.read(authProvider).value?.token;
      if (token != null) {
        try {
          await ref.read(apiClientProvider).updateProfile(token, themeMode: value);
        } catch (_) {
          // Responsive local cache ensures UI consistency even if sync is delayed
        }
      }
    }
  }

  Future<void> syncFromAccount(String themeModeStr) async {
    final mode = themeModeStr == 'dark' ? ThemeMode.dark : ThemeMode.light;
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
