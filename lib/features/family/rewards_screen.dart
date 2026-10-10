import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/translations.dart';
import '../../models/family.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

/// Mirrors mobile/app/(app)/family/rewards.tsx.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final _daily = TextEditingController(text: '0');
  final _weekly = TextEditingController(text: '0');
  final _monthly = TextEditingController(text: '0');
  final _yearly = TextEditingController(text: '0');
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _daily.dispose();
    _weekly.dispose();
    _monthly.dispose();
    _yearly.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .updateFamilyStreakSettings(
            token,
            FamilyStreakSettings(
              dailyStreakReward: int.tryParse(_daily.text) ?? 0,
              weeklyStreakReward: int.tryParse(_weekly.text) ?? 0,
              monthlyStreakReward: int.tryParse(_monthly.text) ?? 0,
              yearlyStreakReward: int.tryParse(_yearly.text) ?? 0,
            ),
          );
      ref.invalidate(familyStreakSettingsProvider);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.t('rewards.alertSavedTitle')),
            content: Text(t.t('rewards.alertSavedMessage')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.t('rewards.alertSaveErrorTitle')),
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
    final settingsAsync = ref.watch(familyStreakSettingsProvider);

    settingsAsync.whenData((settings) {
      if (!_hydrated) {
        _hydrated = true;
        _daily.text = '${settings.dailyStreakReward}';
        _weekly.text = '${settings.weeklyStreakReward}';
        _monthly.text = '${settings.monthlyStreakReward}';
        _yearly.text = '${settings.yearlyStreakReward}';
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F5FF),
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('rewards.title'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                if (!isParent)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      t.t('rewards.parentOnlyTitle'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    LightText(t.t('rewards.parentOnlyDescription')),
                  ],
                ),
              )
            else
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.t('rewards.sectionTitle'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    LightText(t.t('rewards.sectionDescription')),
                    const SizedBox(height: 10),
                    _Field(label: t.t('rewards.dailyLabel'), controller: _daily),
                    const SizedBox(height: 8),
                    _Field(label: t.t('rewards.weeklyLabel'), controller: _weekly),
                    const SizedBox(height: 8),
                    _Field(
                      label: t.t('rewards.monthlyLabel'),
                      controller: _monthly,
                    ),
                    const SizedBox(height: 8),
                    _Field(label: t.t('rewards.yearlyLabel'), controller: _yearly),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : () => _save(t),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _saving ? t.t('rewards.saving') : t.t('rewards.save'),
                      ),
                    ),
                  ],
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
          ),
        ),
      ],
    );
  }
}
