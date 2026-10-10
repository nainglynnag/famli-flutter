import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';
import '../l10n/translations.dart';

/// Mirrors mobile/src/context/I18nContext.tsx: persisted language choice,
/// hydrated from secure storage on start.
class I18nNotifier extends Notifier<SupportedLanguage> {
  final SecureStorage _storage = SecureStorage();

  @override
  SupportedLanguage build() {
    _hydrate();
    return defaultLanguage;
  }

  Future<void> _hydrate() async {
    final stored = await _storage.read(Env.languageStorageKey);
    final language = languageFromCode(stored);
    if (language != null) {
      state = language;
    }
  }

  Future<void> setLanguage(SupportedLanguage language) async {
    state = language;
    await _storage.write(Env.languageStorageKey, languageCode(language));
  }
}

final i18nProvider = NotifierProvider<I18nNotifier, SupportedLanguage>(
  I18nNotifier.new,
);

final translationsProvider = Provider<Map<String, dynamic>>((ref) {
  final language = ref.watch(i18nProvider);
  return translations[language]!;
});
