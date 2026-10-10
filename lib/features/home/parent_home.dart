import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/privilege.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';

/// Mirrors the ParentHome component in mobile/app/(app)/home.tsx.
class ParentHome extends ConsumerStatefulWidget {
  const ParentHome({super.key, required this.profile});

  final UserSummary profile;

  @override
  ConsumerState<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends ConsumerState<ParentHome> {
  String? _selectedChildId;

  Future<void> _completeForChild(String taskId, String childId) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    try {
      await ref.read(apiClientProvider).completeTask(
            token,
            taskId,
            childId: childId,
            status: 'COMPLETED',
          );
      ref.invalidate(tasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final language = ref.watch(i18nProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final pointsAsync = ref.watch(todayPointEntriesProvider);
    final privilegesAsync = ref.watch(privilegeRequestsProvider);
    final familyAsync = ref.watch(familyMembersProvider);

    final children = (familyAsync.value ?? [])
        .where((m) => m.role == UserRole.child)
        .toList();

    Future<void> handleRefresh() async {
      ref.invalidate(tasksProvider);
      ref.invalidate(todayPointEntriesProvider);
      ref.invalidate(privilegeRequestsProvider);
      ref.invalidate(familyMembersProvider);
      await Future.wait([
        ref.read(tasksProvider.future),
        ref.read(todayPointEntriesProvider.future),
        ref.read(privilegeRequestsProvider.future),
        ref.read(familyMembersProvider.future),
      ]);
    }

    final tasks = tasksAsync.value ?? [];
    final pendingAssignments = <_AssignmentRow>[];
    final completedAssignments = <_AssignmentRow>[];
    for (final task in tasks) {
      for (final assignment in task.assignments ?? const <TaskAssignment>[]) {
        if (!assignment.isApplicableToday) continue;
        if (_selectedChildId != null && assignment.childId != _selectedChildId) {
          continue;
        }
        final row = _AssignmentRow(
          taskId: task.id,
          taskTitle: task.title,
          childId: assignment.childId,
          childName: assignment.childName,
          status: assignment.status,
          childAvatarTone: assignment.childAvatarTone,
          childPhotoUrl: assignment.childPhotoUrl,
          routineName: task.routineName,
          dueAt: task.dueAt,
        );
        if (assignment.status == 'COMPLETED') {
          completedAssignments.add(row);
        } else {
          pendingAssignments.add(row);
        }
      }
    }

    final privilegeRequests = privilegesAsync.value ?? [];
    final pendingPrivileges = privilegeRequests
        .where((r) => r.status == PrivilegeRequestStatus.pending)
        .take(3)
        .toList();
    final activeTickets = privilegeRequests
        .where((r) => r.status == PrivilegeRequestStatus.approved)
        .take(3)
        .toList();
    final hasPrivilegeData = privilegeRequests.isNotEmpty;
    final todayPointEntries = pointsAsync.value ?? [];

    final totalApplicable = pendingAssignments.length + completedAssignments.length;
    final completedApplicable = completedAssignments.length;

    return Column(
      children: [
        StickyTopBar(
          title: homeGreeting(language, widget.profile.name),
          subtitle: t.t('home.subtitleParent'),
          showBackButton: false,
          showNotificationBell: true,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: handleRefresh,
            color: AppColors.brandPrimary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              children: [
                // Family Day Pulse Hero Card
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedChildId == null
                                            ? (widget.profile.family?.name ??
                                                t.t('home.familyLabel'))
                                            : (children
                                                    .where((c) =>
                                                        c.id == _selectedChildId)
                                                    .firstOrNull
                                                    ?.name ??
                                                'Child'),
                                        style: _valueStyle(isDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandPrimary.withValues(
                                            alpha: isDark ? 0.25 : 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'TODAY',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: isDark
                                              ? const Color(0xFFA5B4FC)
                                              : AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedChildId == null
                                      ? 'Household Daily Pulse'
                                      : 'Individual Daily Pulse',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (totalApplicable > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (completedApplicable == totalApplicable
                                        ? AppColors.progressEmerald
                                        : AppColors.brandPrimary)
                                    .withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (completedApplicable == totalApplicable
                                          ? AppColors.progressEmerald
                                          : AppColors.brandPrimary)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${((completedApplicable / totalApplicable) * 100).round()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: completedApplicable == totalApplicable
                                      ? (isDark
                                          ? const Color(0xFF6EE7B7)
                                          : AppColors.progressEmeraldDark)
                                      : (isDark
                                          ? const Color(0xFFA5B4FC)
                                          : AppColors.brandPrimary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (tasksAsync.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SproutLoadingIndicator(size: 28),
                          ),
                        )
                      else if (totalApplicable == 0)
                        Row(
                          children: [
                            const Text('🌱', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No tasks scheduled for today',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$completedApplicable of $totalApplicable Tasks Done',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (completedApplicable == totalApplicable)
                              Row(
                                children: [
                                  const Icon(Icons.stars_rounded,
                                      color: AppColors.progressEmerald, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '100%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : AppColors.progressEmeraldDark,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (completedApplicable / totalApplicable)
                                .clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completedApplicable == totalApplicable
                                  ? AppColors.progressEmerald
                                  : AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          completedApplicable == totalApplicable
                              ? 'All tasks complete! 🎉 Outstanding work today!'
                              : (completedApplicable >= (totalApplicable / 2)
                                  ? 'Great progress today! 💪 Over halfway done.'
                                  : '${totalApplicable - completedApplicable} tasks remaining for today.'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: completedApplicable == totalApplicable
                                ? (isDark
                                    ? const Color(0xFF6EE7B7)
                                    : AppColors.progressEmeraldDark)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionCardHeader(
                        title: t.t('home.assignmentsTitle'),
                        trailing: StatusPill(label: t.t('home.pendingLabel')),
                      ),
                      if (children.length > 1) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All'),
                              selected: _selectedChildId == null,
                              onSelected: (_) =>
                                  setState(() => _selectedChildId = null),
                            ),
                            ...children.map(
                              (c) => ChoiceChip(
                                avatar: UserAvatarCircle(
                                  name: c.name,
                                  photoUrl: c.photoUrl,
                                  avatarTone: c.avatarTone,
                                  size: 18,
                                ),
                                label: Text(c.name),
                                selected: _selectedChildId == c.id,
                                onSelected: (_) =>
                                    setState(() => _selectedChildId = c.id),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (pendingAssignments.isEmpty)
                        if (totalApplicable > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF064E3B)
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFDCFCE7),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.progressEmerald, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'All caught up! No pending tasks right now ✨',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (tasksAsync.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: SproutLoadingView(
                              message: 'Loading tasks...',
                              size: SproutLoadingSize.small,
                            ),
                          )
                        else
                          LightText(t.t('home.noPending'))
                      else
                        ...pendingAssignments.map(
                          (a) => _AssignmentTile(
                            row: a,
                            onTap: () => context.go('/tasks/${a.taskId}'),
                            onCheckComplete: () =>
                                _completeForChild(a.taskId, a.childId),
                          ),
                        ),
                TextButton(
                  onPressed: () => context.go('/history'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    t.t('home.viewHistory'),
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (completedAssignments.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCardHeader(
                    title: t.t('home.recentWins'),
                    trailing: StatusPill(
                      label: t.t('home.completedLabel'),
                      tone: PillTone.completed,
                    ),
                  ),
                  ...completedAssignments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarDot(tone: a.childAvatarTone),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${a.childName} finished ${a.taskTitle}',
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasPrivilegeData) ...[
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCardHeader(
                    title: t.t('home.privilegesTitle'),
                    trailing: TextButton(
                      onPressed: () => context.go('/family/privileges'),
                      child: Text(
                        t.t('home.manage'),
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Text(t.t('home.pendingRequests'), style: _labelStyle),
                  if (pendingPrivileges.isEmpty)
                    LightText(t.t('home.noPendingRequests'))
                  else
                    ...pendingPrivileges.map(
                      (r) => _PrivilegeRow(
                        tone: r.childAvatarTone,
                        title: r.privilege.title,
                        subtitle:
                            '${r.childName ?? t.t('home.childFallback')} • ${r.cost} ${t.t('home.seedsSuffix')}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(t.t('home.activeTickets'), style: _labelStyle),
                  if (activeTickets.isEmpty)
                    LightText(t.t('home.noActiveTickets'))
                  else
                    ...activeTickets.map(
                      (r) => _PrivilegeRow(
                        tone: r.childAvatarTone,
                        title: r.privilege.title,
                        subtitle:
                            '${r.childName ?? t.t('home.childFallback')} • ${r.cost} ${t.t('home.seedsSuffix')}',
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (todayPointEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCardHeader(
                    title: t.t('home.giftsTitle'),
                    trailing: TextButton(
                      onPressed: () => context.go('/points'),
                      child: Text(
                        t.t('home.managePoints'),
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ...todayPointEntries.map((entry) {
                    final isGift = entry.points >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AvatarDot(tone: entry.child?.avatarTone),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.child?.name ??
                                      t.t('home.childFallback'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                                Text(
                                  '${isGift ? '+' : ''}${entry.points} ${t.t('home.seedsSuffix')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isGift
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                                if (entry.note != null) LightText(entry.note!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  ),
],
);
  }
}

const _labelStyle = TextStyle(
  color: Color(0xFF94A3B8),
  fontSize: 12,
  letterSpacing: 1.2,
);
TextStyle _valueStyle(bool isDark) => TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : const Color(0xFF111827),
);

class _AssignmentRow {
  _AssignmentRow({
    required this.taskId,
    required this.taskTitle,
    required this.childId,
    required this.childName,
    required this.status,
    this.childAvatarTone,
    this.childPhotoUrl,
    this.routineName,
    this.dueAt,
  });

  final String taskId;
  final String taskTitle;
  final String childId;
  final String childName;
  final String status;
  final String? childAvatarTone;
  final String? childPhotoUrl;
  final String? routineName;
  final DateTime? dueAt;
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.row,
    required this.onTap,
    required this.onCheckComplete,
  });

  final _AssignmentRow row;
  final VoidCallback onTap;
  final VoidCallback onCheckComplete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = row.status == 'OVERDUE';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isOverdue
                ? (isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                    : const Color(0xFFFEF2F2))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isOverdue
                ? Border.all(
                    color: isDark
                        ? const Color(0xFF991B1B)
                        : const Color(0xFFFECACA),
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatarCircle(
                name: row.childName,
                photoUrl: row.childPhotoUrl,
                avatarTone: row.childAvatarTone,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.taskTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Overdue',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.childName}${row.routineName != null ? ' • ${row.routineName}' : ''}${row.dueAt != null ? ' • Due: ${formatDueDateTime(row.dueAt!)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCheckComplete,
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6C63FF),
                ),
                tooltip: 'Mark Complete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivilegeRow extends StatelessWidget {
  const _PrivilegeRow({
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final String? tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarDot(tone: tone),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
