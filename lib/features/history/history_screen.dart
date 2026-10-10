import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../providers/i18n_provider.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';

/// Mirrors mobile/app/(app)/history.tsx.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _selectedChild;
  late Future<List<TaskHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TaskHistoryEntry>> _load() {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return Future.value([]);
    return ref
        .read(apiClientProvider)
        .fetchTaskHistory(token, childId: _selectedChild);
  }

  void _selectChild(String? childId) {
    setState(() {
      _selectedChild = childId;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final familyAsync = isParent
        ? ref.watch(familyMembersProvider)
        : const AsyncValue.data([]);
    final children = (familyAsync.value ?? [])
        .where((m) => m.role == UserRole.child)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F5FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: [
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/home'),
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
                    '← ${t.t('history.back')}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.t('history.title'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2933),
                    ),
                  ),
                ),
              ],
            ),
            if (isParent) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: t.t('history.filterAll'),
                      active: _selectedChild == null,
                      onTap: () => _selectChild(null),
                    ),
                    ...children.map(
                      (child) => _FilterChip(
                        label: child.name,
                        active: _selectedChild == child.id,
                        onTap: () => _selectChild(child.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            FutureBuilder<List<TaskHistoryEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    ),
                  );
                }
                final entries = snapshot.data ?? [];
                return Column(
                  children: entries
                      .map(
                        (entry) => _HistoryCard(
                          entry: entry,
                          isParent: isParent,
                          t: t,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE))
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE4E4E7)),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.isParent,
    required this.t,
  });

  final TaskHistoryEntry entry;
  final bool isParent;
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = entry.status == 'COMPLETED';
    final date = DateTime.tryParse(entry.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.taskTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              StatusPill(
                label: completed
                    ? t.t('history.statusCompleted')
                    : t.t('history.statusPending'),
                tone: completed ? PillTone.completed : PillTone.pending,
              ),
            ],
          ),
          Text(
            date != null
                ? '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                : '',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
          ),
          if (isParent)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  AvatarDot(tone: entry.childAvatarTone, size: 10),
                  const SizedBox(width: 8),
                  Text(
                    entry.childName ?? '',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                  ),
                ],
              ),
            )
          else
            Text(
              '${entry.points ?? 0} ${t.t('history.seedsEarnedSuffix')}',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
            ),
        ],
      ),
    );
  }
}
