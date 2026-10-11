import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../constants/timezones.dart';
import '../../core/api_exception.dart';
import '../../l10n/translations.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/sprout_loading.dart';
import 'widgets/language_toggle.dart';

/// Mirrors mobile/app/(auth)/register.tsx.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _familyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _familyNameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(Map<String, dynamic> t) async {
    final familyName = _familyNameController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if ([familyName, name, email, username, password].any((v) => v.isEmpty)) {
      _showAlert(
        t.t('auth.register.missingInfoTitle'),
        t.t('auth.register.missingInfoMessage'),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String? timezone;
      try {
        final resolved = await FlutterTimezone.getLocalTimezone();
        timezone = resolved.identifier;
      } catch (_) {
        final offset = DateTime.now().timeZoneOffset;
        final match = findTimezoneByOffset(offset);
        timezone = match?.name;
      }

      await ref
          .read(authProvider.notifier)
          .registerParent(
            RegisterParentPayload(
              familyName: familyName,
              timezone: timezone,
              parent: RegisterParentDetails(
                name: name,
                username: username.toLowerCase(),
                email: email.toLowerCase(),
                password: password,
              ),
            ),
          );
      if (mounted) context.go('/home');
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      _showAlert(t.t('auth.register.signUpErrorTitle'), message);
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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
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
                    child: LanguageToggle(
                      activeColor: Color(0xFFE0F2F1),
                      activeTextColor: Color(0xFF0F766E),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('auth.register.title'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2933),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.t('auth.register.subtitle'),
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          label: t.t('auth.register.familyNameLabel'),
                          child: TextField(
                            controller: _familyNameController,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              t.t('auth.register.familyNamePlaceholder'),
                              isDark: Theme.of(context).brightness == Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: t.t('auth.register.yourNameLabel'),
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              t.t('auth.register.yourNamePlaceholder'),
                              isDark: Theme.of(context).brightness == Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: t.t('auth.register.emailLabel'),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              t.t('auth.register.emailPlaceholder'),
                              isDark: Theme.of(context).brightness == Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: t.t('auth.register.usernameLabel'),
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              t.t('auth.register.usernamePlaceholder'),
                              isDark: Theme.of(context).brightness == Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          label: t.t('auth.register.passwordLabel'),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              t.t('auth.register.passwordPlaceholder'),
                              isDark: Theme.of(context).brightness == Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => _handleRegister(t),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2EC4B6),
                              enabledMouseCursor: SystemMouseCursors.click,
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
                                      ? t.t('auth.register.creating')
                                      : t.t('auth.register.create'),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              t.t('auth.register.haveAccount'),
                              style: const TextStyle(color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(width: 6),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  t.t('auth.register.signIn'),
                                  style: const TextStyle(
                                    color: Color(0xFF2EC4B6),
                                    fontWeight: FontWeight.w600,
                                  ),
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

InputDecoration _inputDecoration(String hint, {bool isDark = false}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF64748B)),
  filled: true,
  fillColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF9FAFB),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB),
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE5E7EB),
    ),
  ),
);

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
