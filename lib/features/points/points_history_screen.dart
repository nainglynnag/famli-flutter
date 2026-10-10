import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/family.dart';
import '../../models/point.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';

/// Mirrors mobile/app/(app)/points/history.tsx.
class PointsHistoryScreen extends ConsumerStatefulWidget {
  const PointsHistoryScreen({super.key});

  @override
  ConsumerState<PointsHistoryScreen> createState() =>
      _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends ConsumerState<PointsHistoryScreen> {
  String? _selectedChild;
  late Future<List<PointEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PointEntry>> _load() {
    final token = ref.read(authProvider).value?.token;
    final profile = ref.read(authProvider).value?.profile;
    if (token == null) return Future.value([]);
    final api = ref.read(apiClientProvider);
    if (profile?.role == UserRole.parent) {
      return api.fetchPointHistory(token, childId: _selectedChild);
    }
    return api.fetchPointEntries(token, limit: 50);
  }

  void _selectChild(String? childId) {
    setState(() {
      _selectedChild = childId;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final familyAsync = isParent
        ? ref.watch(familyMembersProvider)
        : const AsyncValue<List<FamilyMember>>.data([]);
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
                  onPressed: () => context.go('/points'),
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
                    '← Back',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Seed Adjustments',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ],
            ),
            if (isParent) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All kids',
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
            FutureBuilder<List<PointEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: SproutLoadingView(
                      message: 'Loading seeds history...',
                      subtitle: 'Fetching earned & spent seeds 🌱',
                      size: SproutLoadingSize.medium,
                    ),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Text(
                    'No entries yet.',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  );
                }
                return Column(
                  children: entries
                      .map(
                        (entry) =>
                            _HistoryCard(entry: entry, isParent: isParent),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
            ),
            borderRadius: BorderRadius.circular(18),
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
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.isParent});

  final PointEntry entry;
  final bool isParent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGift = entry.points >= 0;
    final color = isGift ? const Color(0xFF16A34A) : const Color(0xFF6366F1);
    final date = DateTime.tryParse(entry.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        borderRadius: BorderRadius.circular(18),
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
              Text(
                isGift ? 'Gift' : 'Penalty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
              Text(
                '${isGift ? '+' : '-'}${entry.points.abs()} seeds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '${date != null ? '${date.month}/${date.day}/${date.year}' : ''}${isParent && entry.child != null ? ' · ${entry.child!.name}' : ''}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          if (isParent && entry.child != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  AvatarDot(tone: entry.child!.avatarTone, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    entry.child!.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (entry.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                entry.note!,
                style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
              ),
            ),
          if (entry.createdBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'By ${entry.createdBy!.name}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
