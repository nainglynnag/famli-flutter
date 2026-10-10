import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/family.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../theme/app_colors.dart';
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
                  child: MemberCard(member: member, t: t),
                ),
              ),
            const SizedBox(height: 8),
            ManageAccountsHeroCard(
              title: t.t('family.manageAccounts'),
              subtitle: 'Family members, invites & parental roles',
              onTap: () => context.push('/family/manage/parents'),
            ),
            if (isParent) ...[
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 320 ? 1 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.35,
                    children: [
                      FeatureCard(
                        title: t.t('family.streakRewards'),
                        subtitle: 'Milestones & bonuses',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AppColors.streakAmber,
                        onTap: () => context.push('/family/rewards'),
                      ),
                      FeatureCard(
                        title: t.t('family.managePrivileges'),
                        subtitle: 'Catalog & requests',
                        icon: Icons.confirmation_number_rounded,
                        accentColor: AppColors.privilegeViolet,
                        onTap: () => context.push('/family/privileges'),
                      ),
                      FeatureCard(
                        title: t.t('family.nudgesReminders'),
                        subtitle: 'Gentle alerts & schedules',
                        icon: Icons.notifications_active_rounded,
                        accentColor: AppColors.nudgeSky,
                        onTap: () => context.push('/family/nudges'),
                      ),
                      FeatureCard(
                        title: t.t('family.giftsPenalties'),
                        subtitle: 'Add or deduct seeds',
                        icon: Icons.stars_rounded,
                        accentColor: AppColors.seedGold,
                        onTap: () => context.go('/points'),
                      ),
                    ],
                  );
                },
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

class ManageAccountsHeroCard extends StatelessWidget {
  const ManageAccountsHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_rounded,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ParentStatBadge extends StatelessWidget {
  const ParentStatBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isDark ? const Color(0xFFA5B4FC) : AppColors.brandPrimary),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.member, required this.t});

  final FamilyOverviewEntry member;
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChild = member.role == UserRole.child;

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
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
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
                  vertical: 5,
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
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
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
          const SizedBox(height: 14),
          if (member.stats.isEmpty)
            LightText(t.t('family.noStats'))
          else if (isChild) ...[
            // Child Badges: Seeds Balance & Streak
            Row(
              children: [
                // Seeds Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.seedGold
                        .withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.seedGold
                          .withValues(alpha: isDark ? 0.45 : 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${(member.stats['seedBalance'] ?? 0).toInt()} Seeds',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFDE047)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Streak Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.streakAmber
                        .withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.streakAmber
                          .withValues(alpha: isDark ? 0.45 : 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${(member.stats['streak'] ?? 0).toInt()} ${(member.stats['streak'] ?? 0).toInt() == 1 ? "day" : "days"}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFDBA74)
                              : const Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Combined Tasks Progress Card (e.g. 7/15 Tasks Completed Today)
            Builder(
              builder: (context) {
                final completed =
                    (member.stats['completedToday'] ?? 0).toInt();
                final total = (member.stats['assignments'] ?? 0).toInt();
                final isFinished = completed >= total && total > 0;
                final progress =
                    total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            total > 0
                                ? '$completed / $total Tasks Completed'
                                : 'No tasks assigned today',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          if (total > 0)
                            if (isFinished)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.progressEmerald
                                      .withValues(alpha: isDark ? 0.25 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '100% Done 🎉',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFF6EE7B7)
                                        : AppColors.progressEmeraldDark,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '${((completed / total) * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFA5B4FC)
                                      : AppColors.brandPrimary,
                                ),
                              ),
                        ],
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFinished
                                  ? AppColors.progressEmerald
                                  : AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            // Parent Stats
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ParentStatBadge(
                  label: 'Tasks Created',
                  value: '${(member.stats['tasksCreated'] ?? 0).toInt()}',
                  icon: Icons.task_alt_rounded,
                  isDark: isDark,
                ),
                ParentStatBadge(
                  label: 'Kids Assigned',
                  value: '${(member.stats['kidsAssigned'] ?? 0).toInt()}',
                  icon: Icons.family_restroom_rounded,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
