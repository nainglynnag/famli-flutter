import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/user_avatar.dart';

/// Mirrors mobile/app/(app)/tasks/[taskId].tsx.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailAsync = ref.watch(taskDetailProvider(taskId));
    final familyAsync = ref.watch(familyMembersProvider);

    Future<void> invalidate() async {
      ref.invalidate(taskDetailProvider(taskId));
      ref.invalidate(tasksProvider);
    }

    Future<void> assign(String childId) async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      await ref.read(apiClientProvider).assignTask(token, taskId, childId);
      await invalidate();
    }

    Future<void> unassign(String childId) async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      await ref.read(apiClientProvider).unassignTask(token, taskId, childId);
      await invalidate();
    }

    Future<void> toggleStatus(String childId, bool markCompleted) async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      await ref
          .read(apiClientProvider)
          .completeTask(
            token,
            taskId,
            childId: childId,
            status: markCompleted ? 'COMPLETED' : 'PENDING',
          );
      await invalidate();
    }

    Future<void> handleDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.t('tasks.deleteTaskConfirmTitle')),
          content: Text(t.t('tasks.deleteTaskConfirmMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.t('tasks.back')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                t.t('tasks.deleteTask'),
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      await ref.read(apiClientProvider).deleteTask(token, taskId);
      if (context.mounted) context.go('/tasks');
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F5FF),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          ),
          error: (error, stack) => Center(
            child: Text(
              t.t('tasks.loadTaskError'),
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
          data: (detail) {
            final children = (familyAsync.value ?? [])
                .where((m) => m.role.name == 'child')
                .toList();
            final assignedIds = detail.assignments
                .map((a) => a.childId)
                .toSet();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/tasks'),
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
                        '← ${t.t('tasks.back')}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        detail.title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1F2933),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t('tasks.rewardLabel'), style: _labelStyle),
                      Text(
                        '${detail.points} ${t.t('tasks.seedsSuffix')}',
                        style: _valueStyle(isDark),
                      ),
                      const SizedBox(height: 6),
                      Text(t.t('tasks.daysLabel'), style: _labelStyle),
                      Text(
                        (detail.daysOfWeek?.isNotEmpty ?? false)
                            ? detail.daysOfWeek!.join(', ')
                            : t.t('tasks.daysAny'),
                        style: _valueStyle(isDark),
                      ),
                      if (detail.dueAt != null) ...[
                        const SizedBox(height: 6),
                        Text(t.t('tasks.deadlineLabel'), style: _labelStyle),
                        Text(
                          formatDueDateTime(detail.dueAt!),
                          style: _valueStyle(isDark),
                        ),
                      ],
                      if (detail.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            detail.description!,
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      if (detail.routineName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${t.t('tasks.partOfRoutine')}${detail.routineName}',
                            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('tasks.assignedChildren'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (detail.assignments.isEmpty)
                        LightText(t.t('tasks.noChildrenAssigned'))
                      else
                        ...detail.assignments.map((assignment) {
                          final completed = assignment.status == 'COMPLETED';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    UserAvatarCircle(
                                      name: assignment.childName,
                                      photoUrl: assignment.childPhotoUrl,
                                      avatarTone: assignment.childAvatarTone,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      assignment.childName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => toggleStatus(
                                        assignment.childId,
                                        !completed,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: completed
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFEEF2FF),
                                        side: BorderSide(
                                          color: completed
                                              ? const Color(0xFF86EFAC)
                                              : const Color(0xFFC7D2FE),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        completed
                                            ? t.t('tasks.undo')
                                            : t.t('tasks.complete'),
                                        style: const TextStyle(
                                          color: Color(0xFF4338CA),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () =>
                                          unassign(assignment.childId),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFFFECACA),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        t.t('tasks.remove'),
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('tasks.childAssignHeader'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      () {
                        final unassignedChildren = children
                            .where((child) => !assignedIds.contains(child.id))
                            .toList();
                        if (children.isEmpty) {
                          return LightText(t.t('tasks.noChildrenAssign'));
                        }
                        if (unassignedChildren.isEmpty) {
                          return LightText(t.t('tasks.allChildrenAssigned'));
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: unassignedChildren.map((child) {
                            return InkWell(
                              onTap: () => assign(child.id),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    UserAvatarCircle(
                                      name: child.name,
                                      photoUrl: child.photoUrl,
                                      avatarTone: child.avatarTone,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      child.name,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('tasks.recentActivity'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (detail.completions.isEmpty)
                        LightText(t.t('tasks.noHistory'))
                      else
                        ...detail.completions.map((completion) {
                          final completed = completion.status == 'COMPLETED';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    UserAvatarCircle(
                                      name: completion.childName,
                                      photoUrl: completion.childPhotoUrl,
                                      avatarTone: completion.childAvatarTone,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          completion.childName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        LightText(_formatDate(completion.date)),
                                      ],
                                    ),
                                  ],
                                ),
                                StatusPill(
                                  label: completed
                                      ? t.t('tasks.taskStatusCompleted')
                                      : t.t('tasks.taskStatusPending'),
                                  tone: completed
                                      ? PillTone.completed
                                      : PillTone.pending,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: handleDelete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      t.t('tasks.deleteTask'),
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.month}/${date.day}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

const _labelStyle = TextStyle(
  fontSize: 12,
  color: Color(0xFF9CA3AF),
  letterSpacing: 1,
);
TextStyle _valueStyle(bool isDark) => TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : const Color(0xFF1F2937),
);
