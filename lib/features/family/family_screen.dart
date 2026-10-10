import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/family.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';

/// Mirrors mobile/app/(app)/family.tsx.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final overviewAsync = ref.watch(familyOverviewProvider);
    final members = overviewAsync.value ?? [];

    return Scaffold(
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('family.title'),
            subtitle: t.t('family.subtitle'),
            showBackButton: false,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
            if (overviewAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (overviewAsync.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overviewAsync.error.toString(),
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        color: const Color(0xFFDC2626),
                        onPressed: () => ref.refresh(familyOverviewProvider),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MemberCard(member: member, t: t),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.push('/family/manage/parents'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(t.t('family.manageAccounts')),
            ),
            if (isParent) ...[
              const SizedBox(height: 10),
              _GhostButton(
                label: t.t('family.streakRewards'),
                onPressed: () => context.push('/family/rewards'),
              ),
              const SizedBox(height: 10),
              _GhostButton(
                label: t.t('family.managePrivileges'),
                onPressed: () => context.push('/family/privileges'),
              ),
              const SizedBox(height: 10),
              _GhostButton(
                label: t.t('family.nudgesReminders'),
                onPressed: () => context.push('/family/nudges'),
              ),
              const SizedBox(height: 10),
              _GhostButton(
                label: t.t('family.giftsPenalties'),
                onPressed: () => context.go('/points'),
              ),
            ],
          ],
        ),
      ),
    ],
  ),
);
}
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        minimumSize: const Size.fromHeight(0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _humanizeStatLabel(String label) {
  final spaced = label
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll('_', ' ')
      .toLowerCase();
  if (spaced.isEmpty) return spaced;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.t});

  final FamilyOverviewEntry member;
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChild = member.role == UserRole.child;
    final stats = member.stats.entries.toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatarCircle(
                name: member.name,
                photoUrl: member.photoUrl,
                avatarTone: member.avatarTone,
                role: member.role,
                size: 44,
                showRoleBadge: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '@${member.username}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? (isChild
                          ? const Color(0xFF0C4A6E).withAlpha(120)
                          : const Color(0xFF312E81).withAlpha(120))
                      : (isChild
                          ? const Color(0xFFECFEFF)
                          : const Color(0xFFF4F3FF)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? (isChild
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF6366F1))
                        : (isChild
                            ? const Color(0xFFBAE6FD)
                            : const Color(0xFFE0E7FF)),
                  ),
                ),
                child: Text(
                  isChild
                      ? t.t('family.roleChild').toUpperCase()
                      : t.t('family.roleParent').toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark
                        ? (isChild
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFFA5B4FC))
                        : (isChild
                            ? const Color(0xFF0369A1)
                            : const Color(0xFF4338CA)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stats.isEmpty)
            LightText(t.t('family.noStats'))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: stats
                  .map(
                    (entry) => Container(
                      constraints: const BoxConstraints(minWidth: 110),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF3F4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: isDark
                            ? Border.all(color: const Color(0xFF334155))
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            _humanizeStatLabel(entry.key),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
