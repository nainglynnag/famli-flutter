import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/nudges.dart';
import '../../l10n/translations.dart';
import '../../models/nudge.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

TimeOfDay? _parseTime(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _formatDisplay(TimeOfDay? time, String fallback) {
  if (time == null) return fallback;
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}

/// Mirrors mobile/app/(app)/family/nudges/[childId].tsx.
class NudgeEditScreen extends ConsumerStatefulWidget {
  const NudgeEditScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<NudgeEditScreen> createState() => _NudgeEditScreenState();
}

class _NudgeEditScreenState extends ConsumerState<NudgeEditScreen> {
  List<NudgeSetting> _drafts = [];
  final Map<String, TextEditingController> _messageControllers = {};
  bool _hydrated = false;
  bool _saving = false;

  TextEditingController _controllerFor(NudgeSetting entry) {
    return _messageControllers.putIfAbsent(
      entry.type,
      () => TextEditingController(text: entry.message ?? ''),
    );
  }

  @override
  void dispose() {
    for (final controller in _messageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateDraft(
    String type, {
    String? time,
    bool? enabled,
  }) {
    setState(() {
      _drafts = _drafts
          .map(
            (entry) => entry.type == type
                ? NudgeSetting(
                    id: entry.id,
                    childId: entry.childId,
                    type: entry.type,
                    label: entry.label,
                    time: time ?? entry.time,
                    enabled: enabled ?? entry.enabled,
                    updatedAt: entry.updatedAt,
                    childName: entry.childName,
                    childAvatarTone: entry.childAvatarTone,
                    message: entry.message,
                  )
                : entry,
          )
          .toList();
    });
  }

  Future<void> _pickTime(NudgeSetting entry) async {
    final initial = _parseTime(entry.time) ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      _updateDraft(entry.type, time: _formatTimeOfDay(picked));
    }
  }

  Future<void> _save(Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;

    final normalized = _drafts.map((entry) {
      final message = _controllerFor(entry).text;
      return NudgeUpdateItem(
        type: entry.type,
        time: entry.time,
        enabled: entry.enabled,
        message: message.isEmpty ? null : message,
      );
    }).toList();

    if (normalized.any((entry) => _parseTime(entry.time) == null)) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.t('nudges.invalidTimeTitle')),
          content: Text(t.t('nudges.invalidTimeMessage')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .updateNudges(token, widget.childId, normalized);
      ref.invalidate(nudgesAdminProvider);
      ref.invalidate(childNudgesProvider(widget.childId));
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.t('nudges.saveErrorTitle')),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isParent) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF),
        body: SafeArea(
          child: Center(child: LightText(t.t('nudges.onlyParents'))),
        ),
      );
    }

    final nudgesAsync = ref.watch(childNudgesProvider(widget.childId));
    nudgesAsync.whenData((data) {
      if (!_hydrated && data.isNotEmpty) {
        _hydrated = true;
        _drafts = data;
      }
    });

    final sorted = _drafts.toList()
      ..sort((a, b) => a.type.compareTo(b.type));
    final childMeta = sorted.isNotEmpty ? sorted.first : null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF),
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('nudges.editTitle'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              children: [
                Row(
                  children: [
                    AvatarDot(tone: childMeta?.childAvatarTone, size: 14),
                    const SizedBox(width: 10),
                    Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childMeta?.childName ?? t.t('nudges.childFallback'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    LightText(t.t('nudges.adjustSubtitle')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (nudgesAsync.isLoading && sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SproutLoadingView(
                  message: 'Loading reminder settings...',
                  size: SproutLoadingSize.medium,
                ),
              )
            else
              ...sorted.map((entry) {
                final template = nudgeTemplateFor(entry.type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
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
                              entry.label.isNotEmpty
                                  ? entry.label
                                  : (template?.label ?? entry.type),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  entry.enabled
                                      ? t.t('nudges.onLabel')
                                      : t.t('nudges.offLabel'),
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Switch(
                                  value: entry.enabled,
                                  onChanged: (value) =>
                                      _updateDraft(entry.type, enabled: value),
                                  activeThumbColor: const Color(0xFF6366F1),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.t('nudges.timeLabel'),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: _saving ? null : () => _pickTime(entry),
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _formatDisplay(
                              _parseTime(entry.time),
                              t.t('nudges.setTime'),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.t('nudges.messageLabel'),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _controllerFor(entry),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                template?.message ??
                                t.t('nudges.friendlyPlaceholder'),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            FilledButton(
              onPressed: _saving ? null : () => _save(t),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? t.t('nudges.saving') : t.t('nudges.save')),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }
}
