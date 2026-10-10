import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_exception.dart';
import '../../l10n/translations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/sprout_loading.dart';
import 'widgets/language_toggle.dart';

/// Mirrors mobile/app/(auth)/login.tsx.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(Map<String, dynamic> t) async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showAlert(
        t.t('auth.login.missingInfoTitle'),
        t.t('auth.login.missingInfoMessage'),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).login(identifier, password);
      if (mounted) context.go('/home');
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      _showAlert(t.t('auth.login.signInErrorTitle'), message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: LanguageToggle(),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('auth.login.title'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1F2933),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.t('auth.login.subtitle'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          label: t.t('auth.login.identifierLabel'),
                          isDark: isDark,
                          child: TextField(
                            controller: _identifierController,
                            textCapitalization: TextCapitalization.none,
                            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(
                              t.t('auth.login.identifierPlaceholder'),
                              isDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          label: t.t('auth.login.passwordLabel'),
                          isDark: isDark,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                            decoration: _inputDecoration(
                              t.t('auth.login.passwordPlaceholder'),
                              isDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _handleLogin(t),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_submitting) ...[
                                  const SproutLoadingIndicator(
                                    size: SproutLoadingSize.mini,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _submitting
                                      ? t.t('auth.login.signingIn')
                                      : t.t('auth.login.signIn'),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              t.t('auth.login.needAccount'),
                              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280)),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.go('/register'),
                              child: Text(
                                t.t('auth.login.createOne'),
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint, bool isDark) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF64748B)),
  filled: true,
  fillColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF9FAFB),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB)),
  ),
);

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, required this.isDark});

  final String label;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
