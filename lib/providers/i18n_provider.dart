import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';
import '../l10n/translations.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Mirrors mobile/src/context/I18nContext.tsx: persisted language choice,
/// hydrated from secure storage on start.
class I18nNotifier extends Notifier<SupportedLanguage> {
  final SecureStorage _storage = SecureStorage();

  @override
  SupportedLanguage build() {
    _hydrate();
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      final prevLang = previous?.value?.profile?.preferences?.language;
      final nextLang = next.value?.profile?.preferences?.language;
      if (nextLang != null && nextLang != prevLang) {
        syncFromAccount(nextLang);
      }
    });
    return defaultLanguage;
  }

  Future<void> _hydrate() async {
    final stored = await _storage.read(Env.languageStorageKey);
    final language = languageFromCode(stored);
    if (language != null) {
      state = language;
      return;
    }
    final accountLang = ref.read(authProvider).value?.profile?.preferences?.language;
    if (accountLang != null) {
      syncFromAccount(accountLang);
    }
  }

  Future<void> setLanguage(SupportedLanguage language, {bool syncToAccount = true}) async {
    state = language;
    final code = languageCode(language);
    await _storage.write(Env.languageStorageKey, code);

    if (syncToAccount) {
      final token = ref.read(authProvider).value?.token;
      if (token != null) {
        try {
          await ref.read(apiClientProvider).updateProfile(token, language: code);
        } catch (_) {
          // Responsive local cache ensures UI consistency even if sync is delayed
        }
      }
    }
  }

  Future<void> syncFromAccount(String languageStr) async {
    final language = languageFromCode(languageStr);
    if (language != null) {
      state = language;
      await _storage.write(Env.languageStorageKey, languageCode(language));
    }
  }
}

final i18nProvider = NotifierProvider<I18nNotifier, SupportedLanguage>(
  I18nNotifier.new,
);

final translationsProvider = Provider<Map<String, dynamic>>((ref) {
  final language = ref.watch(i18nProvider);
  return translations[language]!;
});
