import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../providers/notifications_center_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import 'widgets/confetti_burst.dart';

class _RoutineGroup {
  _RoutineGroup({
    required this.id,
    required this.name,
    required this.tasks,
    this.daysOfWeek,
  });

  final String id;
  final String name;
  final List<TaskSummary> tasks;
  final List<String>? daysOfWeek;
}

/// Mirrors the ChildHome component in mobile/app/(app)/home.tsx.
class ChildHome extends ConsumerStatefulWidget {
  const ChildHome({super.key, required this.profile});

  final UserSummary profile;

  @override
  ConsumerState<ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends ConsumerState<ChildHome> {
  String? _expandedTaskId;
  int _confettiTrigger = 0;

  void _toggleTask(String taskId) {
    setState(() => _expandedTaskId = _expandedTaskId == taskId ? null : taskId);
  }

  Future<void> _completeTask(String taskId, bool markCompleted) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    await ref
        .read(apiClientProvider)
        .completeTask(
          token,
          taskId,
          status: markCompleted ? 'COMPLETED' : 'PENDING',
        );
    ref.invalidate(tasksProvider);
    unawaited(ref.read(authProvider.notifier).refreshProfile());
    if (markCompleted) {
      setState(() => _confettiTrigger += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final language = ref.watch(i18nProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final streakAsync = ref.watch(familyStreakSettingsProvider);
    final pointsAsync = ref.watch(todayPointEntriesProvider);
    final seedBalanceAsync = ref.watch(childSeedBalanceProvider);
    final currentSeedBalance =
        seedBalanceAsync.value ?? widget.profile.progress?.seedBalance ?? 0;

    ref.listen(myPrivilegeRequestsProvider, (previous, next) {
      if (previous != null && next.hasValue) {
        unawaited(ref.read(authProvider.notifier).refreshProfile());
      }
    });

    Future<void> handleRefresh() async {
      ref.invalidate(tasksProvider);
      ref.invalidate(familyStreakSettingsProvider);
      ref.invalidate(todayPointEntriesProvider);
      ref.invalidate(childSeedBalanceProvider);
      await Future.wait([
        ref.read(tasksProvider.future),
        ref.read(familyStreakSettingsProvider.future),
        ref.read(todayPointEntriesProvider.future),
        ref.read(authProvider.notifier).refreshProfile(),
      ]);
    }

    final tasks = tasksAsync.value ?? [];
    final manualTasks = tasks
        .where((task) => task.routineName == null && task.routineId == null)
        .toList();
    final routineGroupsMap = <String, _RoutineGroup>{};
    for (final task in tasks) {
      if (task.routineId != null || task.routineName != null) {
        final key = task.routineId ?? task.routineName!;
        final name = task.routineName ?? 'Routine';
        routineGroupsMap.putIfAbsent(
          key,
          () => _RoutineGroup(
            id: key,
            name: name,
            tasks: [],
            daysOfWeek: task.daysOfWeek,
          ),
        );
        routineGroupsMap[key]!.tasks.add(task);
      }
    }
    final routineGroups = routineGroupsMap.values.toList();

    final completedCount = tasks
        .where((task) => task.status == 'COMPLETED')
        .length;
    final remainingTasks = (tasks.length - completedCount).clamp(
      0,
      tasks.length,
    );
    final streakCount = widget.profile.progress?.streak ?? 0;
    final streakSettings = streakAsync.value;

    final streakGoals = <_StreakGoal>[
      if ((streakSettings?.dailyStreakReward ?? 0) > 0)
        _StreakGoal('Daily', 1, streakSettings!.dailyStreakReward),
      if ((streakSettings?.weeklyStreakReward ?? 0) > 0)
        _StreakGoal('Weekly', 7, streakSettings!.weeklyStreakReward),
      if ((streakSettings?.monthlyStreakReward ?? 0) > 0)
        _StreakGoal('Monthly', 31, streakSettings!.monthlyStreakReward),
    ];
    final maxThreshold = streakGoals.isNotEmpty
        ? streakGoals.last.threshold
        : 0;
    final streakProgress = maxThreshold > 0
        ? (streakCount / maxThreshold).clamp(0.0, 1.0)
        : (streakGoals.isNotEmpty ? (streakCount > 0 ? 1.0 : 0.0) : 0.0);

    final childPointEntries = pointsAsync.value ?? [];
    final notificationsState = ref.watch(notificationsCenterProvider);
    final unreadPointEntries = childPointEntries
        .where((entry) => !notificationsState.readIds.contains('point_${entry.id}'))
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            StickyTopBar(
              title: homeGreeting(language, widget.profile.name),
              subtitle: t.t('home.subtitleChild'),
              showBackButton: false,
              showNotificationBell: true,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: handleRefresh,
                color: const Color(0xFF6C63FF),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('home.familyLabel'), style: _labelStyle),
                    Text(
                      widget.profile.family?.name ?? t.t('home.notLinked'),
                      style: _valueStyle(isDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Tasks Done
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF312E81) : const Color(0xFFDFE3FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('home.todayLabel').toUpperCase(),
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$completedCount / ${tasks.length}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                  ),
                                ),
                                Text(
                                  'tasks done',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LightText(
                              remainingTasks == 0
                                  ? t.t('home.allDone')
                                  : remainingTasks == 1
                                  ? t.t('home.remainingSingle')
                                  : homeRemainingPlural(language, remainingTasks),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Column: Total Seeds
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('home.seedsLabel').toUpperCase(),
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('🌱', style: TextStyle(fontSize: 22)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '$currentSeedBalance',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : const Color(0xFF78350F),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Total seeds',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Available to spend',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...unreadPointEntries.map((entry) {
                final isGift = entry.points >= 0;
                final notiId = 'point_${entry.id}';
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Dismissible(
                    key: ValueKey(notiId),
                    direction: DismissDirection.horizontal,
                    onDismissed: (_) {
                      ref.read(notificationsCenterProvider.notifier).markAsRead(notiId);
                    },
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: (isGift ? AppColors.progressEmerald : AppColors.penaltyCoral).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: isGift ? AppColors.progressEmerald : AppColors.penaltyCoral,
                      ),
                    ),
                    secondaryBackground: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: (isGift ? AppColors.progressEmerald : AppColors.penaltyCoral).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: isGift ? AppColors.progressEmerald : AppColors.penaltyCoral,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? (isGift ? const Color(0xFF166534) : const Color(0xFF991B1B))
                              : (isGift ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isGift ? AppColors.progressEmerald : AppColors.penaltyCoral)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              isGift
                                  ? t.t('home.pointGiftIcon')
                                  : t.t('home.pointPenaltyIcon'),
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${isGift ? '+' : '-'}${entry.points.abs()} ${t.t('home.seedsSuffix')}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isGift
                                            ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                            : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      tooltip: 'Dismiss',
                                      onPressed: () {
                                        ref.read(notificationsCenterProvider.notifier).markAsRead(notiId);
                                      },
                                    ),
                                  ],
                                ),
                                if (entry.note != null && entry.note!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.note!,
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      backgroundColor: (isGift ? AppColors.progressEmerald : AppColors.brandPrimary)
                                          .withValues(alpha: isDark ? 0.2 : 0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      ref.read(notificationsCenterProvider.notifier).markAsRead(notiId);
                                    },
                                    icon: const Icon(Icons.check_rounded, size: 14),
                                    label: const Text(
                                      'Got it 👍',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (streakGoals.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.t('home.streakRewards'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          Text(
                            '$streakCount ${t.t('home.streakDays')}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4C1D95),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: streakProgress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? const Color(0xFF312E81)
                              : const Color(0xFFEDE9FE),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: streakGoals
                            .map(
                              (goal) => Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.label.toUpperCase(),
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF475569),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '+${goal.reward} ${t.t('home.seedsSuffix')}',
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : const Color(0xFF1E1B4B),
                                        fontWeight: FontWeight.w600,
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
                ),
              ],
              if (manualTasks.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('home.myTasks'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...manualTasks.map(
                        (task) => _TaskCard(
                          task: task,
                          expanded: _expandedTaskId == task.id,
                          t: t,
                          onTap: () => _toggleTask(task.id),
                          onToggleComplete: () => _completeTask(
                            task.id,
                            task.status != 'COMPLETED',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ...routineGroups.map((group) {
                final routineComplete = group.tasks.every(
                  (task) => task.status == 'COMPLETED',
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionCardHeader(
                          title: group.name,
                          trailing: StatusPill(
                            label: routineComplete
                                ? t.t('home.taskStatusCompleted')
                                : t.t('home.routineInProgress'),
                            tone: routineComplete
                                ? PillTone.completed
                                : PillTone.pending,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            for (int i = 0; i < group.tasks.length; i += 3)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (int j = 0; j < 3; j++)
                                        if (i + j < group.tasks.length)
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                left: j == 0 ? 0 : 4,
                                                right: j == 2 ? 0 : 4,
                                              ),
                                              child: _RoutineGridTaskCard(
                                                task: group.tasks[i + j],
                                                expanded: _expandedTaskId ==
                                                    group.tasks[i + j].id,
                                                t: t,
                                                onTap: () => _toggleTask(
                                                  group.tasks[i + j].id,
                                                ),
                                                onToggleComplete: () =>
                                                    _completeTask(
                                                  group.tasks[i + j].id,
                                                  group.tasks[i + j].status !=
                                                      'COMPLETED',
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          const Expanded(
                                            child: SizedBox(),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/history'),
                  icon: const Icon(Icons.history_rounded, size: 20),
                  label: Text(
                    t.t('home.actions.taskHistory'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF4B5563),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
  Positioned(
    top: 60,
    left: 0,
    right: 0,
    child: ConfettiBurst(trigger: _confettiTrigger),
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

class _StreakGoal {
  _StreakGoal(this.label, this.threshold, this.reward);

  final String label;
  final int threshold;
  final num reward;
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.expanded,
    required this.t,
    required this.onTap,
    required this.onToggleComplete,
  });

  final TaskSummary task;
  final bool expanded;
  final Map<String, dynamic> t;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = task.status == 'COMPLETED';
    final isOverdue = task.status == 'OVERDUE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF86EFAC)
                  : isOverdue
                  ? const Color(0xFFFCA5A5)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
              width: (isCompleted || isOverdue) ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? const Color(0xFF4ADE80)
                                : isOverdue
                                ? const Color(0xFFEF4444)
                                : (isDark ? Colors.white : const Color(0xFF1F2937)),
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${task.points} ${t.t('home.seedsSuffix')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.dueAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2))
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOverdue
                              ? const Color(0xFFEF4444)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: isOverdue
                                ? const Color(0xFFEF4444)
                                : (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatDueDateTime(task.dueAt!),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isOverdue
                                  ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isCompleted
                    ? t.t('home.taskStatusCompleted')
                    : isOverdue
                    ? t.t('home.taskStatusOverdue')
                    : t.t('home.taskStatusPending'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : isOverdue
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFEA580C),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: onToggleComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: isCompleted
                          ? const Color(0xFF4B5563)
                          : const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isCompleted ? t.t('home.undo') : t.t('home.markComplete'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineGridTaskCard extends StatelessWidget {
  const _RoutineGridTaskCard({
    required this.task,
    required this.expanded,
    required this.t,
    required this.onTap,
    required this.onToggleComplete,
  });

  final TaskSummary task;
  final bool expanded;
  final Map<String, dynamic> t;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = task.status == 'COMPLETED';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF86EFAC)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
            width: isCompleted ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 38,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                        color: isCompleted
                            ? const Color(0xFF4ADE80)
                            : (isDark ? Colors.white : const Color(0xFF1F2937)),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task.points} ${t.t('home.seedsSuffix')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCompleted
                      ? t.t('home.taskStatusCompleted')
                      : t.t('home.taskStatusPending'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: onToggleComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: isCompleted
                        ? const Color(0xFF4B5563)
                        : const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isCompleted ? t.t('home.undo') : t.t('home.markComplete'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
