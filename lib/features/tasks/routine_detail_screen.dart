import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../models/routine.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

const _days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// Mirrors mobile/app/(app)/tasks/routines/[templateId].tsx.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailAsync = ref.watch(routineTemplateDetailProvider(templateId));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          ),
          error: (error, stack) => Center(
            child: Text(
              t.t('tasks.loadRoutineError'),
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
          data: (detail) =>
              _RoutineForm(templateId: templateId, detail: detail, t: t),
        ),
      ),
    );
  }
}

class _ItemForm {
  _ItemForm({String title = '', String points = '1'})
    : titleController = TextEditingController(text: title),
      pointsController = TextEditingController(text: points);

  final TextEditingController titleController;
  final TextEditingController pointsController;

  void dispose() {
    titleController.dispose();
    pointsController.dispose();
  }
}

class _RoutineForm extends ConsumerStatefulWidget {
  const _RoutineForm({
    required this.templateId,
    required this.detail,
    required this.t,
  });

  final String templateId;
  final RoutineTemplate detail;
  final Map<String, dynamic> t;

  @override
  ConsumerState<_RoutineForm> createState() => _RoutineFormState();
}

class _RoutineFormState extends ConsumerState<_RoutineForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late List<String> _selectedDays;
  late List<_ItemForm> _items;
  late Set<String> _assignedChildIds;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.detail.name);
    _descriptionController = TextEditingController(
      text: widget.detail.description ?? '',
    );
    _selectedDays = (widget.detail.daysOfWeek?.isNotEmpty ?? false)
        ? List.of(widget.detail.daysOfWeek!)
        : List.of(_days);
    _items = widget.detail.items.isNotEmpty
        ? widget.detail.items
              .map(
                (item) =>
                    _ItemForm(title: item.title, points: '${item.points}'),
              )
              .toList()
        : [_ItemForm()];
    _assignedChildIds =
        (widget.detail.assignments ?? []).map((a) => a.childId).toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
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

  Future<void> _handleSave() async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.updateRoutineTemplate(
        token,
        widget.templateId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        daysOfWeek: _selectedDays,
        items: _items
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

      final initialIds =
          (widget.detail.assignments ?? []).map((a) => a.childId).toSet();
      final toAssign = _assignedChildIds.difference(initialIds);
      final toUnassign = initialIds.difference(_assignedChildIds);

      for (final childId in toAssign) {
        try {
          await api.assignRoutineTemplate(token, widget.templateId, childId);
        } catch (_) {}
      }
      for (final childId in toUnassign) {
        try {
          await api.unassignRoutineTemplate(token, widget.templateId, childId);
        } catch (_) {}
      }

      ref.invalidate(routineTemplateDetailProvider(widget.templateId));
      ref.invalidate(routineTemplatesProvider);
      ref.invalidate(tasksProvider);
      ref.invalidate(familyOverviewProvider);
      if (mounted) {
        _showAlert(
          widget.t.t('tasks.routineUpdatedTitle'),
          widget.t.t('tasks.routineUpdatedMessage'),
        );
      }
    } catch (error) {
      if (mounted) {
        _showAlert(widget.t.t('tasks.templateSaveError'), error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.t.t('tasks.deleteRoutineConfirmTitle')),
        content: Text(widget.t.t('tasks.deleteRoutineConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(widget.t.t('tasks.back')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              widget.t.t('tasks.deleteRoutine'),
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(apiClientProvider)
          .deleteRoutineTemplate(token, widget.templateId);
      ref.invalidate(routineTemplatesProvider);
      ref.invalidate(tasksProvider);
      if (mounted) context.go('/tasks');
    } catch (error) {
      if (mounted) {
        _showAlert(widget.t.t('tasks.deleteRoutineError'), error.toString());
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayLabels =
        (t['tasks'] as Map<String, dynamic>)['dayLabels']
            as Map<String, dynamic>? ??
        {};
    final familyAsync = ref.watch(familyMembersProvider);
    final children = (familyAsync.value ?? [])
        .where((m) => m.role == UserRole.child)
        .toList();

    return Column(
      children: [
        StickyTopBar(
          title: widget.detail.name.isNotEmpty
              ? widget.detail.name
              : t.t('tasks.createRoutine'),
          showBackButton: true,
          onBack: () => context.go('/tasks'),
          showNotificationBell: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.t('tasks.routineNameLabel'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              _TextField(
                controller: _nameController,
                hint: t.t('tasks.routineNamePlaceholder'),
              ),
              const SizedBox(height: 12),
              Text(
                t.t('tasks.descriptionLabel'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              _TextField(
                controller: _descriptionController,
                hint: t.t('tasks.routineDescriptionPlaceholder'),
              ),
              const SizedBox(height: 12),
              Text(
                t.t('tasks.daysActiveLabel'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((day) {
                  final active = _selectedDays.contains(day);
                  return InkWell(
                    onTap: () => setState(() {
                      _selectedDays = active
                          ? _selectedDays.where((d) => d != day).toList()
                          : [..._selectedDays, day];
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE))
                            : Colors.transparent,
                        border: Border.all(
                          color: active
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFD4D4D8)),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dayLabels[day] as String? ?? day,
                        style: TextStyle(
                          color: active
                              ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                              : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                '${_items.length} ${t.t('tasks.routineTasksLabel')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              ..._items.asMap().entries.map((entry) {
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
                      if (_items.length > 1)
                        TextButton(
                          onPressed: () => setState(() {
                            item.dispose();
                            _items = List.of(_items)..removeAt(index);
                          }),
                          child: Text(
                            t.t('tasks.removeTask'),
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              TextButton(
                onPressed: () =>
                    setState(() => _items = [..._items, _ItemForm()]),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  t.t('tasks.addRoutineTask'),
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
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
                'Assign to Children',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 4),
              LightText('Select which children should receive this routine:'),
              const SizedBox(height: 12),
              if (children.isEmpty)
                LightText(t.t('tasks.noAssigned'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children.map((child) {
                    final isSelected = _assignedChildIds.contains(child.id);
                    return InkWell(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _assignedChildIds.remove(child.id);
                        } else {
                          _assignedChildIds.add(child.id);
                        }
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6)),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
                            width: isSelected ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF9CA3AF)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              child.name,
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA))
                                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _handleSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _saving ? t.t('tasks.saving') : t.t('tasks.saveRoutine'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _deleting ? null : _handleDelete,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFECACA)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _deleting
                  ? t.t('tasks.deleteRoutineLoading')
                  : t.t('tasks.deleteRoutine'),
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
            ],
          ),
        ),
      ],
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
