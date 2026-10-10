import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../constants/timezones.dart';
import '../../core/api_exception.dart';
import '../../core/notifications.dart';
import '../../l10n/translations.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/i18n_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/theme_mode_toggle.dart';
import '../../widgets/user_avatar.dart';
import '../auth/widgets/language_toggle.dart';
import 'package:image_picker/image_picker.dart';

/// Mirrors mobile/app/(app)/profile.tsx: display name, avatar tone, family
/// timezone (parents only), password change, test notification, and logout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _currentPassword = TextEditingController();
  late final TextEditingController _newPassword = TextEditingController();
  late final TextEditingController _familyTimezone;
  final FocusNode _timezoneFocus = FocusNode();

  late String _avatarTone;
  bool _showTimezoneSuggestions = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).value?.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _avatarTone = profile?.avatarTone ?? 'sunrise';
    _familyTimezone = TextEditingController(
      text: profile?.family?.timezone ?? '',
    );
    _timezoneFocus.addListener(() {
      if (!_timezoneFocus.hasFocus) {
        setState(() => _showTimezoneSuggestions = false);
      }
    });
    if (_familyTimezone.text.isEmpty) {
      _resolveDeviceTimezone();
    }
  }

  Future<void> _resolveDeviceTimezone() async {
    try {
      final resolved = await FlutterTimezone.getLocalTimezone();
      if (mounted && _familyTimezone.text.isEmpty) {
        _familyTimezone.text = resolved.identifier;
      }
    } catch (_) {
      // Leave the field blank if the platform can't resolve a timezone.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _familyTimezone.dispose();
    _timezoneFocus.dispose();
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

  Future<void> _pickAndSavePhoto(Map<String, dynamic> t) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final profile = ref.read(authProvider).value?.profile;
    final token = ref.read(authProvider).value?.token;
    if (profile == null || token == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await picked.readAsBytes();
      final storageService = ref.read(imageStorageServiceProvider);
      final ext = picked.name.split('.').lastOrNull ?? 'jpg';
      final pathOrUrl = await storageService.saveProfileImage(
        userId: profile.id,
        bytes: bytes,
        extension: ext,
      );

      await ref.read(apiClientProvider).updateProfile(
        token,
        photoUrl: pathOrUrl,
      );
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        AppToast.showSuccess(context, 'Profile photo updated successfully!');
      }
    } catch (e) {
      if (mounted) _showAlert('Photo Upload Failed', e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto(Map<String, dynamic> t) async {
    final profile = ref.read(authProvider).value?.profile;
    final token = ref.read(authProvider).value?.token;
    if (profile == null || token == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      if (profile.photoUrl != null && profile.photoUrl!.isNotEmpty) {
        final storageService = ref.read(imageStorageServiceProvider);
        await storageService.deleteProfileImage(
          userId: profile.id,
          imageRef: profile.photoUrl!,
        );
      }

      await ref.read(apiClientProvider).updateProfile(
        token,
        photoUrl: '',
      );
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) {
        AppToast.showSuccess(context, 'Profile photo removed.');
      }
    } catch (e) {
      if (mounted) AppToast.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save(Map<String, dynamic> t) async {
    if (_name.text.trim().isEmpty) {
      AppToast.showError(context, t.t('profile.alertNameRequiredMessage'));
      return;
    }

    final authState = ref.read(authProvider).value;
    final token = authState?.token;
    if (token == null) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .updateProfile(
            token,
            name: _name.text.trim(),
            avatarTone: _avatarTone,
            currentPassword: _currentPassword.text.isEmpty
                ? null
                : _currentPassword.text,
            newPassword: _newPassword.text.isEmpty ? null : _newPassword.text,
            familyTimezone: authState?.profile?.role == UserRole.parent
                ? _familyTimezone.text.trim()
                : null,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) {
        AppToast.showSuccess(context, t.t('profile.alertUpdatedMessage'));
      }
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      if (mounted) AppToast.showError(context, message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _triggerTestNotification(Map<String, dynamic> t) async {
    await NotificationService.instance.ensurePermissions();
    await NotificationService.instance.showTestNotification(
      title: t.t('profile.testNotificationTitle'),
      body: t.t('profile.testNotificationBody'),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;

    final toneLabels = (t['profile'] as Map<String, dynamic>?)?['toneLabels']
            as Map<String, dynamic>? ??
        const {};

    final query = _familyTimezone.text.trim().toLowerCase();
    final suggestions = (query.isEmpty
            ? commonTimezones
            : commonTimezones
                .where(
                  (tz) =>
                      tz.name.toLowerCase().contains(query) ||
                      tz.offset.toLowerCase().contains(query),
                )
                .toList())
        .take(8)
        .toList();

    return Column(
      children: [
        StickyTopBar(
          title: t.t('profile.title'),
          subtitle: t.t('profile.subtitle'),
          showBackButton: context.canPop(),
          showNotificationBell: true,
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemeModeToggle(),
              SizedBox(width: 8),
              LanguageToggle(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              UserAvatarCircle(
                                name: profile?.name ?? 'User',
                                photoUrl: profile?.photoUrl,
                                avatarTone: _avatarTone,
                                role: profile?.role,
                                size: 92,
                                showRoleBadge: true,
                                borderWidth: 3,
                                borderColor: Colors.white,
                              ),
                              if (_uploadingPhoto)
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _uploadingPhoto
                                    ? null
                                    : () => _pickAndSavePhoto(t),
                                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                                label: Text(
                                  profile?.photoUrl != null &&
                                          profile!.photoUrl!.isNotEmpty
                                      ? 'Change Photo'
                                      : 'Upload Photo',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  foregroundColor: const Color(0xFF4C1D95),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                              if (profile?.photoUrl != null &&
                                  profile!.photoUrl!.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: _uploadingPhoto
                                      ? null
                                      : () => _removePhoto(t),
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  label: const Text(
                                    'Remove',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(
                                      color: Color(0xFFFCA5A5),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFFF1F5F9), height: 1),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                    if (profile?.username != null) ...[
                      Text(
                        t.t('profile.usernameLabel'),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile!.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _FieldLabel(t.t('profile.displayNameLabel')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _name,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(context),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: toneColors.keys
                          .where((tone) => tone != 'default')
                          .map((tone) {
                        final active = _avatarTone == tone;
                        return GestureDetector(
                          onTap: () => setState(() => _avatarTone = tone),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? (isDark ? const Color(0xFF4338CA).withValues(alpha: 0.5) : const Color(0xFFEDE9FE))
                                  : null,
                              border: Border.all(
                                color: active
                                    ? (isDark ? const Color(0xFF818CF8) : const Color(0xFFC4B5FD))
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: toneColor(tone),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (toneLabels[tone] as String?) ?? tone,
                                  style: TextStyle(
                                    color: active
                                        ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (isParent) ...[
                      const SizedBox(height: 12),
                      _FieldLabel(t.t('profile.familyTimezoneLabel')),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _familyTimezone,
                        focusNode: _timezoneFocus,
                        autocorrect: false,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        onTap: () =>
                            setState(() => _showTimezoneSuggestions = true),
                        onChanged: (_) =>
                            setState(() => _showTimezoneSuggestions = true),
                        decoration: _inputDecoration(context),
                      ),
                      if (_showTimezoneSuggestions && suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView(
                            shrinkWrap: true,
                            children: suggestions.map((tz) {
                              return InkWell(
                                onTap: () {
                                  _familyTimezone.text = tz.name;
                                  setState(
                                    () => _showTimezoneSuggestions = false,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    '${tz.name} (${tz.offset})',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    _FieldLabel(t.t('profile.currentPasswordLabel')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _currentPassword,
                      obscureText: true,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        context,
                        hint: t.t('profile.currentPasswordPlaceholder'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel(t.t('profile.newPasswordLabel')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newPassword,
                      obscureText: true,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(context),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : () => _save(t),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _saving ? t.t('profile.saving') : t.t('profile.save'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _triggerTestNotification(t),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          t.t('profile.testNotification'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                      height: 1,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          t.t('profile.logout'),
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
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(BuildContext context, {String? hint}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
    ),
    filled: true,
    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF475569),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
