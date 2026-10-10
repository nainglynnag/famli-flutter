import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../l10n/translations.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

/// Dedicated screen for changing account password.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  InputDecoration _passwordDecoration(
    BuildContext context, {
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      suffixIcon: IconButton(
        icon: Icon(
          isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          size: 20,
        ),
        onPressed: onToggle,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _handleSubmit(Map<String, dynamic> t) async {
    final current = _currentPassword.text.trim();
    final newPass = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    if (current.isEmpty) {
      AppToast.showError(context, t.t('profile.currentPasswordRequired'));
      return;
    }
    if (newPass.length < 6) {
      AppToast.showError(context, t.t('profile.passwordMinLength'));
      return;
    }
    if (newPass != confirm) {
      AppToast.showError(context, t.t('profile.passwordMismatch'));
      return;
    }

    final token = ref.read(authProvider).value?.token;
    if (token == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).updateProfile(
            token,
            currentPassword: current,
            newPassword: newPass,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        AppToast.showSuccess(context, t.t('profile.passwordChangedSuccess'));
        context.pop();
      }
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      if (mounted) AppToast.showError(context, message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('profile.changePassword'),
            subtitle: t.t('profile.changePasswordSubtitle'),
            showBackButton: true,
            showNotificationBell: false,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.25 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_reset_rounded,
                              size: 26,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('profile.changePasswordTitle'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.t('profile.changePasswordDesc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 18),

                      // Current Password
                      Text(
                        t.t('profile.currentPasswordLabel'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _currentPassword,
                        obscureText: _obscureCurrent,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _passwordDecoration(
                          context,
                          hint: t.t('profile.currentPasswordPlaceholder'),
                          isObscure: _obscureCurrent,
                          onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      Text(
                        t.t('profile.newPasswordLabel'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _newPassword,
                        obscureText: _obscureNew,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _passwordDecoration(
                          context,
                          hint: t.t('profile.passwordMinLength'),
                          isObscure: _obscureNew,
                          onToggle: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm New Password
                      Text(
                        t.t('profile.confirmPasswordLabel'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _confirmPassword,
                        obscureText: _obscureConfirm,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: _passwordDecoration(
                          context,
                          hint: t.t('profile.confirmPasswordPlaceholder'),
                          isObscure: _obscureConfirm,
                          onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : () => _handleSubmit(t),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _submitting
                              ? const SproutLoadingIndicator(
                                  size: SproutLoadingSize.mini,
                                  color: Colors.white,
                                )
                              : Text(
                                  t.t('profile.updatePasswordButton'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
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
