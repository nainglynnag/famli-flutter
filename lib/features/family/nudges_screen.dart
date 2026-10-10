import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
import '../../constants/nudges.dart';
import '../../core/secure_storage.dart';
import '../../l10n/translations.dart';
import '../../models/nudge.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';

String _formatDisplayTime(String? value, String fallback) {
  if (value == null) return fallback;
  final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(value);
  if (match == null) return value;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final time = TimeOfDay(hour: hour, minute: minute);
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  final displayHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

/// Mirrors mobile/app/(app)/family/nudges.tsx:
/// upgraded with StickyTopBar, UserAvatarCircle, Global Nudge Rules,
/// and Parent Missing Tasks Check-in Reminder.
class NudgesScreen extends ConsumerStatefulWidget {
  const NudgesScreen({super.key});

  @override
  ConsumerState<NudgesScreen> createState() => _NudgesScreenState();
}

class _NudgesScreenState extends ConsumerState<NudgesScreen> {
  String? _savingChildId;
  final SecureStorage _storage = SecureStorage();

  bool _parentReminderEnabled = true;
  String _parentReminderTime = '20:00';

  final List<Map<String, dynamic>> _globalNudges = defaultNudges
      .map(
        (t) => <String, dynamic>{
          'type': t.type,
          'time': t.time,
          'enabled': true,
          'message': t.message,
          'label': t.label,
        },
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadParentReminder();
  }

  Future<void> _loadParentReminder() async {
    final stored = await _storage.read(Env.parentReminderStorageKey);
    if (stored != null) {
      final parts = stored.split('|');
      if (parts.isNotEmpty) _parentReminderEnabled = parts[0] == 'true';
      if (parts.length > 1) _parentReminderTime = parts[1];
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveParentReminder(bool enabled, String time) async {
    setState(() {
      _parentReminderEnabled = enabled;
      _parentReminderTime = time;
    });
    await _storage.write(Env.parentReminderStorageKey, '$enabled|$time');
    if (mounted) {
      AppToast.showSuccess(
        context,
        'Parent reminder updated (${_formatDisplayTime(time, time)})',
      );
    }
  }

  Future<void> _pickParentReminderTime() async {
    final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(_parentReminderTime);
    final initialHour = match != null ? int.parse(match.group(1)!) : 20;
    final initialMin = match != null ? int.parse(match.group(2)!) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await _saveParentReminder(_parentReminderEnabled, formatted);
    }
  }

  Future<void> _toggle(
    NudgeSetting entry,
    bool enabled,
    Map<String, dynamic> t,
  ) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _savingChildId = entry.childId);
    try {
      await ref
          .read(apiClientProvider)
          .updateNudges(token, entry.childId, [
            NudgeUpdateItem(
              type: entry.type,
              time: entry.time,
              enabled: enabled,
              message: entry.message,
            ),
          ]);
      ref.invalidate(nudgesAdminProvider);
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _savingChildId = null);
    }
  }

  final Map<String, bool> _useGlobalByChild = {};
  bool _loadedGlobalStates = false;

  Future<void> _loadUseGlobalStates(List<String> childIds) async {
    if (_loadedGlobalStates) return;
    _loadedGlobalStates = true;
    for (final id in childIds) {
      final val = await _storage.read('famli-nudge-use-global-$id');
      _useGlobalByChild[id] = val != 'false';
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleUseGlobal(
    String childId,
    bool useGlobal,
    Map<String, dynamic> t,
  ) async {
    setState(() {
      _useGlobalByChild[childId] = useGlobal;
    });
    await _storage.write('famli-nudge-use-global-$childId', '$useGlobal');

    if (useGlobal) {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      setState(() => _savingChildId = childId);
      try {
        final api = ref.read(apiClientProvider);
        final updateItems = _globalNudges
            .map(
              (m) => NudgeUpdateItem(
                type: m['type'] as String,
                time: m['time'] as String,
                enabled: m['enabled'] as bool,
                message: m['message'] as String?,
              ),
            )
            .toList();
        await api.updateNudges(token, childId, updateItems);
        ref.invalidate(nudgesAdminProvider);
        if (mounted) {
          AppToast.showSuccess(
            context,
            'Synced with global rules 🔄',
          );
        }
      } catch (error) {
        if (mounted) {
          AppToast.showError(context, error.toString());
        }
      } finally {
        if (mounted) setState(() => _savingChildId = null);
      }
    }
  }

  Future<void> _applyGlobalToAll(
    List<String> childIds,
    Map<String, dynamic> t,
  ) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null || childIds.isEmpty) return;
    setState(() => _savingChildId = 'global');
    try {
      final api = ref.read(apiClientProvider);
      final updateItems = _globalNudges
          .map(
            (m) => NudgeUpdateItem(
              type: m['type'] as String,
              time: m['time'] as String,
              enabled: m['enabled'] as bool,
              message: m['message'] as String?,
            ),
          )
          .toList();
      for (final cid in childIds) {
        await api.updateNudges(token, cid, updateItems);
        _useGlobalByChild[cid] = true;
        await _storage.write('famli-nudge-use-global-$cid', 'true');
      }
      ref.invalidate(nudgesAdminProvider);
      if (mounted) {
        AppToast.showSuccess(context, t.t('nudges.applyGlobalSuccess'));
      }
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _savingChildId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;

    if (!isParent) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: LightText(t.t('nudges.onlyParents'))),
        ),
      );
    }

    final nudgesAsync = ref.watch(nudgesAdminProvider);
    final familyAsync = ref.watch(familyMembersProvider);
    final data = nudgesAsync.value ?? [];
    final familyMembers = familyAsync.value ?? [];

    final grouped = <String, List<NudgeSetting>>{};
    for (final entry in data) {
      grouped.putIfAbsent(entry.childId, () => []).add(entry);
    }
    final allChildIds = grouped.keys.toList();
    if (allChildIds.isNotEmpty) {
      _loadUseGlobalStates(allChildIds);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('nudges.title'),
            subtitle: t.t('nudges.subtitle'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: nudgesAsync.isLoading && data.isEmpty
                ? const SproutLoadingView(
                    message: 'Loading nudges & reminders...',
                    size: SproutLoadingSize.medium,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                    children: [
                      // ---- SECTION 1: GLOBAL SETTING FOR ALL CHILDREN ----
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.public_rounded,
                                    color: Color(0xFF6C63FF),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.t('nudges.globalRulesTitle'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        t.t('nudges.globalRulesSubtitle'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ..._globalNudges.map((nudge) {
                              final label = nudge['label'] as String;
                              final time = nudge['time'] as String;
                              final enabled = nudge['enabled'] as bool;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '$label (${_formatDisplayTime(time, time)})',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: enabled,
                                      onChanged: (val) {
                                        setState(() {
                                          nudge['enabled'] = val;
                                        });
                                      },
                                      activeThumbColor: const Color(0xFF6366F1),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _savingChildId == 'global'
                                    ? null
                                    : () =>
                                        _applyGlobalToAll(allChildIds, t),
                                icon: _savingChildId == 'global'
                                    ? const SproutLoadingIndicator(
                                        size: SproutLoadingSize.mini,
                                        color: Colors.white,
                                      )
                                    : const Icon(Icons.sync_rounded, size: 18),
                                label: Text(t.t('nudges.applyGlobal')),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---- SECTION 2: PARENT MISSING TASKS REMINDER ----
                      SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.alarm_on_rounded,
                                    color: Color(0xFFD97706),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.t('nudges.parentReminderTitle'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      Text(
                                        t.t('nudges.parentReminderSubtitle'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _parentReminderEnabled,
                                  onChanged: (val) => _saveParentReminder(
                                    val,
                                    _parentReminderTime,
                                  ),
                                  activeThumbColor: const Color(0xFFD97706),
                                ),
                              ],
                            ),
                            if (_parentReminderEnabled) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${t.t('nudges.parentReminderTime')}: ${_formatDisplayTime(_parentReminderTime, _parentReminderTime)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _pickParentReminderTime,
                                    child: const Text(
                                      'Change Time',
                                      style: TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ---- SECTION 3: CHILD SPECIFIC NUDGES & PROFILES ----
                      if (grouped.isEmpty)
                        SectionCard(
                          child: LightText(t.t('nudges.noChildren')),
                        )
                      else
                        ...grouped.entries.map((group) {
                          final childId = group.key;
                          final nudges = group.value;
                          final childMeta = nudges.first;
                          final saving = _savingChildId == childId;
                          final childMember = familyMembers
                              .where((m) => m.id == childId)
                              .firstOrNull;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SectionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      UserAvatarCircle(
                                        name: childMember?.name ??
                                            childMeta.childName ??
                                            'Child',
                                        photoUrl: childMember?.photoUrl,
                                        avatarTone: childMember?.avatarTone ??
                                            childMeta.childAvatarTone,
                                        role: UserRole.child,
                                        size: 38,
                                        showRoleBadge: true,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            childMember?.name ??
                                                childMeta.childName ??
                                                t.t('nudges.childFallback'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: isDark ? Colors.white : const Color(0xFF111827),
                                            ),
                                          ),
                                          LightText(t.t('nudges.dailyNudges')),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Switch to use same as global rules
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.public_rounded,
                                          size: 18,
                                          color: (_useGlobalByChild[childId] ?? true)
                                              ? const Color(0xFF6C63FF)
                                              : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Use same as global rules',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1E293B),
                                                ),
                                              ),
                                              Text(
                                                (_useGlobalByChild[childId] ?? true)
                                                    ? 'Following global schedule'
                                                    : 'Customized for this child',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? const Color(0xFF94A3B8)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _useGlobalByChild[childId] ?? true,
                                          onChanged: saving
                                              ? null
                                              : (val) => _toggleUseGlobal(
                                                    childId,
                                                    val,
                                                    t,
                                                  ),
                                          activeThumbColor: const Color(0xFF6366F1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_useGlobalByChild[childId] ?? true) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFC7D2FE),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: Color(0xFF10B981),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Using global reminder schedule. Turn off the switch above to customize individually.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : const Color(0xFF4338CA),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    ...nudges.map((entry) {
                                      final template =
                                          nudgeTemplateFor(entry.type);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.label.isNotEmpty
                                                        ? entry.label
                                                        : (template?.label ??
                                                            entry.type),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${t.t('nudges.timeLabel')}: ${_formatDisplayTime(entry.time, t.t('nudges.setTime'))}',
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(0xFF94A3B8)
                                                          : const Color(0xFF6B7280),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    entry.message?.isNotEmpty ==
                                                            true
                                                        ? entry.message!
                                                        : (template?.message ??
                                                            t.t(
                                                              'nudges.localReminder',
                                                            )),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? const Color(0xFFCBD5E1)
                                                          : const Color(0xFF475569),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              children: [
                                                Text(
                                                  entry.enabled
                                                      ? t.t('nudges.onLabel')
                                                      : t.t('nudges.offLabel'),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? const Color(0xFF94A3B8)
                                                        : const Color(0xFF475569),
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Switch(
                                                  value: entry.enabled,
                                                  onChanged: saving
                                                      ? null
                                                      : (value) => _toggle(
                                                            entry,
                                                            value,
                                                            t,
                                                          ),
                                                  activeThumbColor:
                                                      const Color(0xFF6366F1),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () => context
                                          .push('/family/nudges/$childId'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: isDark
                                              ? const Color(0xFF475569)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                        minimumSize: const Size.fromHeight(42),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Text(
                                        t.t('nudges.editTimes'),
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFCBD5E1)
                                              : const Color(0xFF1F2937),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
