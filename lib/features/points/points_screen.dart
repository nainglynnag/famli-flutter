import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../models/point.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

/// Mirrors mobile/app/(app)/points/index.tsx.
class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  String? _childId;
  PointEntryType _type = PointEntryType.gift;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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

  Future<void> _handleSubmit(Map<String, dynamic> t) async {
    if (_childId == null) {
      _showAlert(
        t.t('points.alertSelectChildTitle'),
        t.t('points.alertSelectChildMessage'),
      );
      return;
    }
    final amount = int.tryParse(_amountController.text)?.abs() ?? 0;
    if (amount == 0) {
      _showAlert(
        t.t('points.alertAmountTitle'),
        t.t('points.alertAmountMessage'),
      );
      return;
    }
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .createPointEntry(
            token,
            childId: _childId!,
            type: _type,
            amount: amount,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      ref.invalidate(pointsScreenEntriesProvider);
      _amountController.clear();
      _noteController.clear();
      if (mounted) {
        _showAlert(
          t.t('points.alertSavedTitle'),
          _type == PointEntryType.gift
              ? t.t('points.alertGiftMessage')
              : t.t('points.alertPenaltyMessage'),
        );
      }
    } catch (error) {
      if (mounted) {
        _showAlert(t.t('points.alertUnableSaveTitle'), error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final entriesAsync = ref.watch(pointsScreenEntriesProvider);
    final familyAsync = isParent
        ? ref.watch(familyMembersProvider)
        : const AsyncValue<List<dynamic>>.data([]);
    final entries = entriesAsync.value ?? [];
    final children = isParent
        ? (familyAsync.value ?? [])
              .where((m) => m.role == UserRole.child)
              .toList()
        : const [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F5FF),
      body: Column(
        children: [
          StickyTopBar(
            title: isParent
                ? t.t('points.titleParent')
                : t.t('points.titleChild'),
            subtitle: t.t('points.subtitle'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.t('points.today'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      if (isParent)
                        TextButton(
                          onPressed: () => context.go('/points/history'),
                          child: Text(
                            t.t('points.viewHistory'),
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (entries.isEmpty)
                    Text(
                      t.t('points.emptyToday'),
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                    )
                  else
                    ...entries.map(
                      (entry) =>
                          _EntryRow(entry: entry, isParent: isParent, t: t),
                    ),
                ],
              ),
            ),
            if (isParent) ...[
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('points.newEntry'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                    ),
                    Text(
                      t.t('points.newEntryHint'),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.t('points.fieldChild'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: children
                            .map<Widget>(
                              (child) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _childId = child.id),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _childId == child.id
                                          ? const Color(0xFFEEF2FF)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _childId == child.id
                                            ? const Color(0xFF818CF8)
                                            : const Color(0xFFD4D4D8),
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AvatarDot(
                                          tone: child.avatarTone,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          child.name,
                                          style: TextStyle(
                                            color: _childId == child.id
                                                ? const Color(0xFF4338CA)
                                                : const Color(0xFF4B5563),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleButton(
                            label: t.t('points.typeGift'),
                            active: _type == PointEntryType.gift,
                            onTap: () =>
                                setState(() => _type = PointEntryType.gift),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ToggleButton(
                            label: t.t('points.typePenalty'),
                            active: _type == PointEntryType.penalty,
                            onTap: () =>
                                setState(() => _type = PointEntryType.penalty),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.t('points.fieldSeeds'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _fieldDecoration(
                        isDark,
                        t.t('points.amountPlaceholder'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.t('points.fieldNote'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _noteController,
                      minLines: 3,
                      maxLines: 5,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _fieldDecoration(
                        isDark,
                        t.t('points.notePlaceholder'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _handleSubmit(t),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _type == PointEntryType.gift
                              ? t.t('points.buttonGift')
                              : t.t('points.buttonPenalty'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
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

InputDecoration _fieldDecoration(bool isDark, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
  filled: true,
  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
  contentPadding: const EdgeInsets.all(12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFD4D4D8)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFD4D4D8)),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFF6366F1), width: 1.5),
  ),
);

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
              : Colors.transparent,
          border: Border.all(
            color: active
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFD4D4D8)),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? (isDark ? Colors.white : const Color(0xFF4338CA))
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isParent,
    required this.t,
  });

  final PointEntry entry;
  final bool isParent;
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGift = entry.points >= 0;
    final color = isGift ? const Color(0xFF16A34A) : const Color(0xFF6366F1);
    final time = DateTime.tryParse(entry.createdAt);
    final timeLabel = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              isGift ? '+' : '-',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
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
                      isGift
                          ? t.t('points.entryGiftLabel')
                          : t.t('points.entryPenaltyLabel'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      '${isGift ? '+' : '-'}${entry.points.abs()} ${t.t('points.seedsSuffix')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (entry.note != null)
                  Text(
                    entry.note!,
                    style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
                  ),
                Text(
                  '$timeLabel${isParent && entry.child != null ? ' · ${entry.child!.name}' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (entry.child != null && isParent)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AvatarDot(tone: entry.child!.avatarTone, size: 12),
            ),
        ],
      ),
    );
  }
}
