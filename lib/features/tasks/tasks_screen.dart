import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/family.dart';
import '../../models/routine.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';

const _days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// Mirrors mobile/app/(app)/tasks/index.tsx.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).value?.profile;
    if (profile == null) return const SizedBox.shrink();

    return profile.role == UserRole.parent
        ? const _ParentTasksView()
        : const _ChildTasksView();
  }
}

class _ChildTasksView extends ConsumerWidget {
  const _ChildTasksView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(tasksProvider);
    final tasks = tasksAsync.value ?? [];

    Future<void> complete(String taskId) async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      await ref
          .read(apiClientProvider)
          .completeTask(token, taskId, status: 'COMPLETED');
      ref.invalidate(tasksProvider);
    }

    return Column(
      children: [
        StickyTopBar(
          title: t.t('tasks.titleChild'),
          showBackButton: false,
          showNotificationBell: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              if (tasks.isEmpty) LightText(t.t('tasks.myTasksEmpty')),
              ...tasks.map((task) {
                final completed = task.status == 'COMPLETED';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB),
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: task.status == 'OVERDUE'
                                    ? const Color(0xFFEF4444)
                                    : (isDark ? Colors.white : const Color(0xFF1F2937)),
                              ),
                            ),
                          ),
                          if (task.status == 'OVERDUE')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.t('tasks.taskStatusOverdue'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      LightText(
                        '${task.points} ${t.t('tasks.seedsSuffix')}${task.routineName != null ? ' • ${task.routineName}' : ''}',
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: completed ? null : () => complete(task.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: completed
                                ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                : const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            completed
                                ? t.t('tasks.done')
                                : t.t('tasks.markComplete'),
                            style: TextStyle(
                              color: completed && isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
    );
  }
}

class _ParentTasksView extends ConsumerStatefulWidget {
  const _ParentTasksView();

  @override
  ConsumerState<_ParentTasksView> createState() => _ParentTasksViewState();
}

class _ParentTasksViewState extends ConsumerState<_ParentTasksView> {
  String _activeTab = 'TASKS';

  final _taskTitleController = TextEditingController();
  final _taskPointsController = TextEditingController(text: '1');
  String? _taskChildId;
  DateTime? _taskDueDateTime;
  bool _creatingTask = false;

  final _templateNameController = TextEditingController();
  final _templateDescriptionController = TextEditingController();
  List<String> _templateDays = List.of(_days);
  List<_TemplateItemForm> _templateItems = [_TemplateItemForm()];
  final Set<String> _templateChildIds = {};
  bool _creatingTemplate = false;

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskPointsController.dispose();
    _templateNameController.dispose();
    _templateDescriptionController.dispose();
    for (final item in _templateItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _taskDueDateTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final initialTime = _taskDueDateTime != null
        ? TimeOfDay.fromDateTime(_taskDueDateTime!)
        : TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _taskDueDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _showAlert(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateTask(Map<String, dynamic> t) async {
    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      _showAlert(
        t.t('tasks.titleRequiredTitle'),
        t.t('tasks.titleRequiredMessage'),
      );
      return;
    }
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;

    setState(() => _creatingTask = true);
    try {
      final api = ref.read(apiClientProvider);
      final createdTaskId = await api.createTask(
        token,
        title: title,
        points: num.tryParse(_taskPointsController.text) ?? 1,
        dueAt: _taskDueDateTime,
      );
      if (_taskChildId != null && createdTaskId != null) {
        await api.assignTask(token, createdTaskId, _taskChildId!);
      }
      ref.invalidate(tasksProvider);
      _taskTitleController.clear();
      _taskPointsController.text = '1';
      setState(() {
        _taskChildId = null;
        _taskDueDateTime = null;
      });
    } catch (error) {
      _showAlert(t.t('tasks.createTaskError'), error.toString());
    } finally {
      if (mounted) setState(() => _creatingTask = false);
    }
  }

  Future<void> _handleCreateTemplate(Map<String, dynamic> t) async {
    final name = _templateNameController.text.trim();
    if (name.isEmpty) {
      _showAlert(
        t.t('tasks.templateNameRequiredTitle'),
        t.t('tasks.templateNameRequiredMessage'),
      );
      return;
    }
    if (_templateItems.isEmpty ||
        _templateItems.first.titleController.text.trim().isEmpty) {
      _showAlert(
        t.t('tasks.templateItemRequiredTitle'),
        t.t('tasks.templateItemRequiredMessage'),
      );
      return;
    }
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;

    setState(() => _creatingTemplate = true);
    try {
      final api = ref.read(apiClientProvider);
      final templateId = await api.createRoutineTemplate(
        token,
        name: name,
        description: _templateDescriptionController.text.trim().isEmpty
            ? null
            : _templateDescriptionController.text.trim(),
        daysOfWeek: _templateDays,
        items: _templateItems
            .map(
              (item) => {
                'title': item.titleController.text.trim().isEmpty
                    ? 'Task'
                    : item.titleController.text.trim(),
                'points': num.tryParse(item.pointsController.text) ?? 1,
              },
            )
            .toList(),
      );
      if (templateId != null && _templateChildIds.isNotEmpty) {
        for (final childId in _templateChildIds) {
          try {
            await api.assignRoutineTemplate(token, templateId, childId);
          } catch (_) {}
        }
      }
      ref.invalidate(routineTemplatesProvider);
      ref.invalidate(tasksProvider);
      _templateNameController.clear();
      _templateDescriptionController.clear();
      setState(() {
        _templateChildIds.clear();
        _templateDays = List.of(_days);
        for (final item in _templateItems) {
          item.dispose();
        }
        _templateItems = [_TemplateItemForm()];
      });
    } catch (error) {
      _showAlert(t.t('tasks.templateSaveError'), error.toString());
    } finally {
      if (mounted) setState(() => _creatingTemplate = false);
    }
  }

  Future<void> _assignTemplate(String templateId, String childId) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    await ref
        .read(apiClientProvider)
        .assignRoutineTemplate(token, templateId, childId);
    ref.invalidate(tasksProvider);
    ref.invalidate(routineTemplatesProvider);
  }

  Future<void> _unassignTemplate(String templateId, String childId) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    await ref
        .read(apiClientProvider)
        .unassignRoutineTemplate(token, templateId, childId);
    ref.invalidate(tasksProvider);
    ref.invalidate(routineTemplatesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final language = ref.watch(i18nProvider);
    final dayLabels =
        (t['tasks'] as Map<String, dynamic>)['dayLabels']
            as Map<String, dynamic>? ??
        {};
    final tasksAsync = ref.watch(tasksProvider);
    final templatesAsync = ref.watch(routineTemplatesProvider);
    final familyAsync = ref.watch(familyMembersProvider);

    final tasks = tasksAsync.value ?? [];
    final manualTasks = tasks
        .where((task) => task.routineName == null)
        .toList();
    final templates = templatesAsync.value ?? [];
    final children = (familyAsync.value ?? [])
        .where((m) => m.role == UserRole.child)
        .toList();

    return Column(
      children: [
        StickyTopBar(
          title: t.t('tasks.titleParent'),
          showBackButton: false,
          showNotificationBell: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                  border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
                ),
                child: Row(
                  children: [
                    _TabButton(
                      label: t.t('tasks.tabTasks'),
                      active: _activeTab == 'TASKS',
                      onTap: () => setState(() => _activeTab = 'TASKS'),
                    ),
                    _TabButton(
                      label: t.t('tasks.tabRoutines'),
                      active: _activeTab == 'ROUTINES',
                      onTap: () => setState(() => _activeTab = 'ROUTINES'),
                    ),
                  ],
                ),
              ),
        const SizedBox(height: 16),
        if (_activeTab == 'TASKS') ...[
          _Section(
            title: t.t('tasks.quickTask'),
            children: [
              _TextField(
                controller: _taskTitleController,
                hint: t.t('tasks.quickTaskPlaceholder'),
              ),
              _TextField(
                controller: _taskPointsController,
                hint: t.t('tasks.pointsPlaceholder'),
                keyboardType: TextInputType.number,
              ),
              InkWell(
                onTap: _pickDueDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _taskDueDateTime != null
                        ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                    border: Border.all(
                      color: _taskDueDateTime != null
                          ? (isDark ? const Color(0xFF6366F1) : const Color(0xFFC7D2FE))
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 20,
                        color: _taskDueDateTime != null
                            ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _taskDueDateTime != null
                              ? '${t.t('tasks.dueAt')}: ${formatDueDateTime(_taskDueDateTime!)}'
                              : t.t('tasks.setDeadline'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _taskDueDateTime != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: _taskDueDateTime != null
                                ? (isDark ? Colors.white : const Color(0xFF3730A3))
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      if (_taskDueDateTime != null)
                        GestureDetector(
                          onTap: () => setState(() => _taskDueDateTime = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children.isEmpty
                    ? [LightText(t.t('tasks.childAddPrompt'))]
                    : children
                          .map(
                            (child) => _ChoiceChip(
                              label: child.name,
                              leading: UserAvatarCircle(
                                name: child.name,
                                photoUrl: child.photoUrl,
                                avatarTone: child.avatarTone,
                                size: 20,
                              ),
                              selected: _taskChildId == child.id,
                              onTap: () =>
                                  setState(() => _taskChildId = child.id),
                            ),
                          )
                          .toList(),
              ),
              _PrimaryButton(
                label: t.t('tasks.createTask'),
                loadingLabel: t.t('tasks.taskPleaseWait'),
                loading: _creatingTask,
                onPressed: () => _handleCreateTask(t),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: t.t('tasks.todaysTasks'),
            children: [
              if (manualTasks.isEmpty)
                LightText(t.t('tasks.noStandaloneTasks')),
              ...manualTasks.map((task) => _ParentTaskCard(task: task, t: t)),
              TextButton(
                onPressed: () => context.go('/history'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  t.t('tasks.viewHistory'),
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          _Section(
            title: t.t('tasks.routineTemplates'),
            children: [
              if (templates.isEmpty) LightText(t.t('tasks.noTemplates')),
              ...templates.map(
                (template) => _TemplateCard(
                  template: template,
                  children: children,
                  dayLabels: dayLabels,
                  language: language,
                  t: t,
                  onAssign: (childId) => _assignTemplate(template.id, childId),
                  onUnassign: (childId) =>
                      _unassignTemplate(template.id, childId),
                  onManage: () => context.go('/tasks/routines/${template.id}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            title: t.t('tasks.createRoutine'),
            children: [
              _TextField(
                controller: _templateNameController,
                hint: t.t('tasks.routineNamePlaceholder'),
              ),
              _TextField(
                controller: _templateDescriptionController,
                hint: t.t('tasks.routineDescriptionPlaceholder'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days
                    .map(
                      (day) => _ChoiceChip(
                        label: dayLabels[day] as String? ?? day,
                        selected: _templateDays.contains(day),
                        onTap: () => setState(() {
                          if (_templateDays.contains(day)) {
                            _templateDays = _templateDays
                                .where((d) => d != day)
                                .toList();
                          } else {
                            _templateDays = [..._templateDays, day];
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              ..._templateItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TextField(
                          controller: item.titleController,
                          hint: 'Task ${index + 1}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: _TextField(
                          controller: item.pointsController,
                          hint: 'Pts',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton(
                onPressed: () => setState(
                  () =>
                      _templateItems = [..._templateItems, _TemplateItemForm()],
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  t.t('tasks.addAnotherTask'),
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Assign to Children',
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (children.isEmpty)
                LightText(t.t('tasks.childAddPromptRoutine'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children.map((c) {
                    final selected = _templateChildIds.contains(c.id);
                    return _ChoiceChip(
                      label: c.name,
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _templateChildIds.remove(c.id);
                        } else {
                          _templateChildIds.add(c.id);
                        }
                      }),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: t.t('tasks.saveTemplate'),
                loadingLabel: t.t('tasks.taskPleaseWait'),
                loading: _creatingTemplate,
                onPressed: () => _handleCreateTemplate(t),
              ),
            ],
          ),
        ],
      ],
    ),
  ),
],
);
  }
}

class _TemplateItemForm {
  _TemplateItemForm()
    : titleController = TextEditingController(),
      pointsController = TextEditingController(text: '1');

  final TextEditingController titleController;
  final TextEditingController pointsController;

  void dispose() {
    titleController.dispose();
    pointsController.dispose();
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF312E81) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          for (final child in children)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Color(0xFF6366F1),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE))
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFD4D4D8)),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          loading ? loadingLabel : label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ParentTaskCard extends ConsumerWidget {
  const _ParentTaskCard({required this.task, required this.t});

  final TaskSummary task;
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignments = task.assignments ?? const <TaskAssignment>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (task.dueAt != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDueDateTime(task.dueAt!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          LightText('${task.points} ${t.t('tasks.seedsSuffix')}'),
          if (assignments.isEmpty)
            LightText(t.t('tasks.noChildrenAssigned'))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignments
                  .map(
                    (a) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UserAvatarCircle(
                            name: a.childName,
                            photoUrl: a.childPhotoUrl,
                            avatarTone: a.childAvatarTone,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            a.childName,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                              fontSize: 12,
                            ),
                          ),
                          if (a.status == 'COMPLETED') ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF22C55E),
                            ),
                          ] else if (a.status == 'OVERDUE') ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: Color(0xFFEF4444),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => GoRouter.of(context).go('/tasks/${task.id}'),
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF312E81).withValues(alpha: 0.5)
                    : const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: isDark ? const BorderSide(color: Color(0xFF4338CA)) : BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t.t('tasks.openTask'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.children,
    required this.dayLabels,
    required this.language,
    required this.t,
    required this.onAssign,
    required this.onUnassign,
    required this.onManage,
  });

  final RoutineTemplate template;
  final List<FamilyMember> children;
  final Map<String, dynamic> dayLabels;
  final SupportedLanguage language;
  final Map<String, dynamic> t;
  final void Function(String childId) onAssign;
  final void Function(String childId) onUnassign;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignments = template.assignments ?? [];
    final assignedIds = assignments.map((a) => a.childId).toSet();
    final unassignedChildren =
        children.where((c) => !assignedIds.contains(c.id)).toList();
    final assignedChildren =
        children.where((c) => assignedIds.contains(c.id)).toList();
    final days = template.daysOfWeek ?? _days;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Top-Right Assigned Children Avatars
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    LightText(
                      '${template.items.length} ${t.t('tasks.routineTasksLabel')}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Top-Right: Already assigned children profile circles
              if (assignments.isNotEmpty)
                Wrap(
                  spacing: -8,
                  children: assignments.map((a) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Tooltip(
                        message: a.childName,
                        child: UserAvatarCircle(
                          name: a.childName,
                          photoUrl: a.childPhotoUrl,
                          avatarTone: a.childAvatarTone,
                          size: 32,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Unassigned',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Days of the week pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: days
                .map(
                  (day) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                      border: Border.all(
                        color: isDark ? const Color(0xFF4338CA) : const Color(0xFFE0E7FF),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dayLabels[day] as String? ?? day,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4C1D95),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6), height: 1),
          const SizedBox(height: 12),

          // Bottom Action Area 1: Assign To (only unassigned children)
          Text(
            'Assign To:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          if (children.isEmpty)
            LightText(t.t('tasks.childAddPromptRoutine'))
          else if (unassignedChildren.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '✓ All children assigned',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unassignedChildren.map((child) {
                return InkWell(
                  onTap: () => onAssign(child.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF312E81).withValues(alpha: 0.4)
                          : const Color(0xFFFAF5FF),
                      border: Border.all(
                        color: isDark ? const Color(0xFF6366F1) : const Color(0xFFDDD6FE),
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
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6D28D9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.add_circle,
                          size: 15,
                          color: isDark ? const Color(0xFF818CF8) : const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          // Bottom Action Area 2: Remove (only assigned children)
          if (assignedChildren.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Remove from Routine:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: assignedChildren.map((child) {
                return InkWell(
                  onTap: () => onUnassign(child.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                          : const Color(0xFFFEF2F2),
                      border: Border.all(
                        color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
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
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.cancel,
                          size: 15,
                          color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF312E81).withValues(alpha: 0.5)
                    : const Color(0xFFEEF2FF),
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: isDark ? const BorderSide(color: Color(0xFF4338CA)) : BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t.t('tasks.openRoutine'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
