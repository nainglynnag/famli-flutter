import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/timezones.dart';
import '../../core/api_exception.dart';
import '../../l10n/translations.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/i18n_provider.dart';
import '../../providers/storage_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';
import 'widgets/timezone_picker_sheet.dart';

/// Reorganized Profile Screen featuring 5 compact groups:
/// 1. Profile: avatar photo, tone palette, display name, username & role.
/// 2. Preferences: labeled theme and language controls (for both parents & children).
/// 3. Security: "Change password" row navigating to separate ChangePasswordScreen.
/// 4. Family Settings: family timezone & device auto-sync (parents only).
/// 5. Account: app tour replay & logout with confirmation.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _familyTimezone;

  late String _avatarTone;
  bool _autoSyncTimezone = false;
  String? _deviceTimezoneId;
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
    _resolveDeviceTimezone();
  }

  Future<void> _resolveDeviceTimezone() async {
    try {
      final resolved = await FlutterTimezone.getLocalTimezone();
      final id = resolved.identifier;
      if (mounted) {
        setState(() {
          _deviceTimezoneId = id;
          if (_familyTimezone.text.isEmpty) {
            _familyTimezone.text = id;
            _autoSyncTimezone = true;
          } else if (_familyTimezone.text == id) {
            _autoSyncTimezone = true;
          }
        });
      }
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      final match = findTimezoneByOffset(offset);
      if (match != null && mounted) {
        setState(() {
          _deviceTimezoneId = match.name;
          if (_familyTimezone.text.isEmpty) {
            _familyTimezone.text = match.name;
            _autoSyncTimezone = true;
          } else if (_familyTimezone.text == match.name) {
            _autoSyncTimezone = true;
          }
        });
      }
    }
  }

  void _toggleAutoSync(bool value) {
    setState(() {
      _autoSyncTimezone = value;
      if (value && _deviceTimezoneId != null) {
        _familyTimezone.text = _deviceTimezoneId!;
      }
    });
  }

  Future<void> _openTimezonePicker(BuildContext context, Map<String, dynamic> t) async {
    final selected = await TimezonePickerSheet.show(
      context,
      selectedTimezone: _familyTimezone.text,
      deviceTimezone: _deviceTimezoneId,
      t: t,
    );
    if (selected != null && mounted) {
      setState(() {
        _familyTimezone.text = selected.name;
        if (_deviceTimezoneId != null && selected.name != _deviceTimezoneId) {
          _autoSyncTimezone = false;
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _familyTimezone.dispose();
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
      await ref.read(apiClientProvider).updateProfile(
            token,
            name: _name.text.trim(),
            avatarTone: _avatarTone,
            familyTimezone: authState?.profile?.role == UserRole.parent
                ? _familyTimezone.text.trim()
                : null,
          );
      await ref.read(authProvider.notifier).refreshProfile();
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

  Future<void> _confirmLogout(Map<String, dynamic> t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            t.t('profile.logoutConfirmTitle'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          content: Text(
            t.t('profile.logoutConfirmMessage'),
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                t.t('profile.cancel'),
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                t.t('profile.logout'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (previous, next) {
      final p = next.value?.profile;
      if (p != null) {
        if (_name.text.isEmpty && p.name.isNotEmpty) {
          _name.text = p.name;
        }
        final famTz = p.family?.timezone;
        if (_familyTimezone.text.isEmpty && famTz != null && famTz.isNotEmpty) {
          setState(() {
            _familyTimezone.text = famTz;
            if (_deviceTimezoneId != null && _deviceTimezoneId == famTz) {
              _autoSyncTimezone = true;
            }
          });
        }
      }
    });

    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;
    final currentTheme = ref.watch(themeModeProvider);
    final currentLang = ref.watch(i18nProvider);

    final toneLabels = (t['profile'] as Map<String, dynamic>?)?['toneLabels']
            as Map<String, dynamic>? ??
        const {};

    final currentTzString = _familyTimezone.text.isNotEmpty
        ? _familyTimezone.text
        : (profile?.family?.timezone ?? _deviceTimezoneId ?? 'UTC');
    final selectedTzOption = findTimezoneByName(currentTzString) ??
        findTimezoneByName(_familyTimezone.text) ??
        findTimezoneByName(_deviceTimezoneId);

    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          // Calm Sticky Header: Title, Subtitle, Notification Bell (no trailing toggles)
          StickyTopBar(
            title: t.t('profile.title'),
            subtitle: t.t('profile.subtitle'),
            showBackButton: context.canPop(),
            showNotificationBell: true,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              // ==========================================
              // GROUP 1: PROFILE
              // ==========================================
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.person_rounded,
                      title: t.t('profile.sectionProfile'),
                    ),
                    const SizedBox(height: 16),
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
                                    child: SproutLoadingIndicator(
                                      color: Colors.white,
                                      size: 36,
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
                                  backgroundColor: isDark
                                      ? const Color(0xFF312E81).withValues(alpha: 0.7)
                                      : const Color(0xFFEDE9FE),
                                  foregroundColor: isDark
                                      ? const Color(0xFFA5B4FC)
                                      : const Color(0xFF4C1D95),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Username & Role Details
                    if (profile?.username != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.t('profile.usernameLabel'),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${profile!.username}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF1F2933),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isParent
                                  ? const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.3 : 0.15)
                                  : const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isParent ? 'PARENT' : 'CHILD',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isParent
                                    ? (isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9))
                                    : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Display Name
                    _FieldLabel(t.t('profile.displayNameLabel')),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _name,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(context),
                    ),
                    const SizedBox(height: 14),

                    // Avatar Tone Chips
                    _FieldLabel('Avatar Tone'),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 16),

                    // Save Profile Button
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
                        child: _saving
                            ? const SproutLoadingIndicator(
                                size: SproutLoadingSize.mini,
                                color: Colors.white,
                              )
                            : Text(
                                t.t('profile.save'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // GROUP 2: PREFERENCES (Parents & Children)
              // ==========================================
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.tune_rounded,
                      title: t.t('profile.sectionPreferences'),
                    ),
                    const SizedBox(height: 14),

                    // Theme Control Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              size: 20,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('profile.themeLabel'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDark ? t.t('profile.themeDark') : t.t('profile.themeLight'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 108,
                            child: SegmentedButton<ThemeMode>(
                              segments: [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  icon: const Icon(Icons.wb_sunny_rounded, size: 16),
                                  tooltip: t.t('profile.themeLight'),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  icon: const Icon(Icons.nightlight_round, size: 16),
                                  tooltip: t.t('profile.themeDark'),
                                ),
                              ],
                              selected: {currentTheme},
                              onSelectionChanged: (selected) {
                                if (selected.isNotEmpty) {
                                  ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
                                }
                              },
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Language Control Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.25 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.language_rounded,
                              size: 20,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('profile.languageLabel'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentLang == SupportedLanguage.mm ? 'မြန်မာ (Myanmar)' : 'English',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 108,
                            child: SegmentedButton<SupportedLanguage>(
                              segments: const [
                                ButtonSegment<SupportedLanguage>(
                                  value: SupportedLanguage.en,
                                  label: Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                                ButtonSegment<SupportedLanguage>(
                                  value: SupportedLanguage.mm,
                                  label: Text('MM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              ],
                              selected: {currentLang},
                              onSelectionChanged: (selected) {
                                if (selected.isNotEmpty) {
                                  ref.read(i18nProvider.notifier).setLanguage(selected.first);
                                }
                              },
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // GROUP 3: SECURITY
              // ==========================================
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.shield_outlined,
                      title: t.t('profile.sectionSecurity'),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => context.push('/profile/change-password'),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.t('profile.changePassword'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.t('profile.changePasswordSubtitle'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ==========================================
              // GROUP 4: FAMILY SETTINGS (Parent-Only)
              // ==========================================
              if (isParent) ...[
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.family_restroom_rounded,
                        title: t.t('profile.sectionFamily'),
                      ),
                      const SizedBox(height: 14),

                      _FieldLabel(t.t('profile.familyTimezoneLabel')),
                      const SizedBox(height: 8),

                      // Auto-Sync Switch Tile
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.sync_rounded,
                                size: 18,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.t('profile.autoSyncTimezone'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    t.t('profile.autoSyncSubtitle'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _autoSyncTimezone,
                              activeTrackColor: const Color(0xFF6C63FF),
                              onChanged: _toggleAutoSync,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Selected Timezone & Location Card
                      InkWell(
                        onTap: _autoSyncTimezone ? null : () => _openTimezonePicker(context, t),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _autoSyncTimezone
                                  ? const Color(0xFF10B981).withValues(alpha: 0.45)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    selectedTzOption?.flag ?? '🌐',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedTzOption?.locationLabel ??
                                              (_familyTimezone.text.isEmpty
                                                  ? 'Select Timezone'
                                                  : _familyTimezone.text),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${selectedTzOption?.name ?? _familyTimezone.text} • ${selectedTzOption?.offset ?? "UTC"}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selectedTzOption != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        selectedTzOption.currentTimeFormatted,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  if (!_autoSyncTimezone) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ],
                                ],
                              ),
                              if (_autoSyncTimezone) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      t.t('profile.autoSyncedBadge'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ==========================================
              // GROUP 5: ACCOUNT
              // ==========================================
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.manage_accounts_outlined,
                      title: t.t('profile.sectionAccount'),
                    ),
                    const SizedBox(height: 14),

                    // App Tour
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/onboarding'),
                        icon: const Icon(Icons.explore_rounded, size: 18, color: Color(0xFF6C63FF)),
                        label: Text(
                          t.t('onboarding.replayTour'),
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmLogout(t),
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                        label: Text(
                          t.t('profile.logout'),
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: isDark
                              ? const Color(0xFF7F1D1D).withValues(alpha: 0.15)
                              : const Color(0xFFFEF2F2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF6C63FF),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.2,
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
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
        fontSize: 13,
      ),
    );
  }
}
