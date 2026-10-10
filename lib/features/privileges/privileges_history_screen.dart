import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../models/privilege.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';

/// Mirrors mobile/app/(app)/privileges/history.tsx.
class PrivilegesHistoryScreen extends ConsumerWidget {
  const PrivilegesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final profileTone = profile?.avatarTone;

    final requestsAsync = isParent
        ? ref.watch(privilegeRequestsProvider)
        : ref.watch(myPrivilegeRequestsProvider);
    final entries = (requestsAsync.value ?? [])
        .where((r) => r.status == PrivilegeRequestStatus.terminated)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F5FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          children: [
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/privileges'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '← ${t.t('privilegesHistory.back')}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isParent
                        ? t.t('privilegesHistory.titleParent')
                        : t.t('privilegesHistory.titleChild'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2933),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isParent
                  ? t.t('privilegesHistory.subtitleParent')
                  : t.t('privilegesHistory.subtitleChild'),
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            if (requestsAsync.hasError)
              LightText(t.t('privilegesHistory.loadErrorFallback'))
            else if (entries.isEmpty)
              LightText(t.t('privilegesHistory.noEntries'))
            else
              ...entries.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AvatarDot(
                            tone: entry.childAvatarTone ?? profileTone,
                            size: 10,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.privilege.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          children: [
                            TextSpan(
                              text: '${t.t('privilegesHistory.costLabel')}: ',
                            ),
                            TextSpan(
                              text:
                                  '${entry.cost} ${t.t('privileges.seedsSuffix')}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                            ),
                          ],
                        ),
                      ),
                      if (isParent)
                        Text.rich(
                          TextSpan(
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            children: [
                              TextSpan(
                                text:
                                    '${t.t('privilegesHistory.childLabel')}: ',
                              ),
                              TextSpan(
                                text:
                                    entry.childName ??
                                    t.t('privilegesHistory.unknownChild'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        '${t.t('privilegesHistory.endedLabel')}: ${_formatDate(entry.resolvedAt ?? entry.createdAt, t.t('privilegesHistory.notAvailable'))}',
                        style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                      if (entry.note != null)
                        Text(
                          '${t.t('privilegesHistory.noteLabel')}: ${entry.note}',
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String? value, String fallback) {
  if (value == null) return fallback;
  final date = DateTime.tryParse(value);
  if (date == null) return fallback;
  return '${date.month}/${date.day}/${date.year}';
}
