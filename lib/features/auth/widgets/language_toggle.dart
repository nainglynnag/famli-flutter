import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/translations.dart';
import '../../../providers/i18n_provider.dart';

/// Mirrors the LanguageToggle component shared by mobile's login/register screens.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({
    super.key,
    this.activeColor = const Color(0xFFEDE9FE),
    this.activeTextColor = const Color(0xFF4C1D95),
  });

  final Color activeColor;
  final Color activeTextColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(i18nProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: SupportedLanguage.values.map((lang) {
          final isActive = lang == current;
          return InkWell(
            onTap: () => ref.read(i18nProvider.notifier).setLanguage(lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: isActive ? activeColor : Colors.transparent,
              child: Text(
                languageCode(lang).toUpperCase(),
                style: TextStyle(
                  color: isActive ? activeTextColor : const Color(0xFF475569),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
