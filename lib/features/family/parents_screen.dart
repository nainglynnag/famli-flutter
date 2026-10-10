import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/family.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/sticky_header.dart';
import '../../widgets/user_avatar.dart';

const _toneColors = {
  'sunrise': Color(0xFFFB923C),
  'forest': Color(0xFF22C55E),
  'ocean': Color(0xFF38BDF8),
  'lavender': Color(0xFFC084FC),
  'sunset': Color(0xFFF87171),
};

/// Mirrors mobile/app/(app)/family/manage/parents.tsx.
class ParentsManageScreen extends ConsumerWidget {
  const ParentsManageScreen({super.key});

  Future<void> _invalidate(WidgetRef ref) async {
    ref.invalidate(familyMembersProvider);
    ref.invalidate(familyOverviewProvider);
  }

  Future<bool> _confirm(
    BuildContext context, {
    required Map<String, dynamic> t,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.t('manageAccounts.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(BuildContext context, String title, Object error) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final token = ref.watch(authProvider).value?.token;
    final membersAsync = ref.watch(familyMembersProvider);
    final members = membersAsync.value ?? [];
    final parents = members.where((m) => m.role == UserRole.parent).toList();
    final children = members.where((m) => m.role == UserRole.child).toList();

    Future<void> saveMember(
      String userId, {
      String? name,
      String? username,
      String? avatarTone,
      String? newPassword,
    }) async {
      if (token == null) return;
      try {
        await ref
            .read(apiClientProvider)
            .updateFamilyMember(
              token,
              userId,
              name: name,
              username: username,
              avatarTone: avatarTone,
              newPassword: newPassword,
            );
        await _invalidate(ref);
      } catch (error) {
        if (context.mounted) _showError(context, 'Unable to save', error);
      }
    }

    Future<void> removeMember(String userId) async {
      if (token == null) return;
      try {
        await ref.read(apiClientProvider).deleteFamilyMember(token, userId);
        await _invalidate(ref);
      } catch (error) {
        if (context.mounted) _showError(context, 'Unable to remove', error);
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F4FF),
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('manageAccounts.title'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                Text(
                  t.t('manageAccounts.parents'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111827)),
                ),
            const SizedBox(height: 10),
            for (var i = 0; i < parents.length; i++) ...[
              _MemberRow(
                member: parents[i],
                t: t,
                onSave: (payload) => saveMember(
                  parents[i].id,
                  name: payload.name,
                  username: payload.username,
                  avatarTone: payload.avatarTone,
                  newPassword: payload.newPassword,
                ),
                onRemove: i == 0
                    ? null
                    : () async {
                        final confirmed = await _confirm(
                          context,
                          t: t,
                          title: t.t('manageAccounts.removeParentTitle'),
                          message: t.t('manageAccounts.removeParentMessage'),
                          confirmLabel: t.t('manageAccounts.remove'),
                        );
                        if (confirmed) await removeMember(parents[i].id);
                      },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            _InviteParentCard(t: t, onInvited: () => _invalidate(ref)),
            const SizedBox(height: 20),
            Text(
              t.t('manageAccounts.children'),
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111827)),
            ),
            const SizedBox(height: 10),
            for (final child in children) ...[
              _MemberRow(
                member: child,
                t: t,
                onSave: (payload) => saveMember(
                  child.id,
                  name: payload.name,
                  username: payload.username,
                  avatarTone: payload.avatarTone,
                  newPassword: payload.newPassword,
                ),
                onRemove: () async {
                  final confirmed = await _confirm(
                    context,
                    t: t,
                    title: t.t('manageAccounts.removeChildTitle'),
                    message: t.t('manageAccounts.removeChildMessage'),
                    confirmLabel: t.t('manageAccounts.remove'),
                  );
                  if (confirmed) await removeMember(child.id);
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            _AddChildCard(t: t, onAdded: () => _invalidate(ref)),
            const SizedBox(height: 20),
            _DeleteFamilyCard(t: t),
          ],
        ),
      ),
    ],
  ),
);
  }
}

class _MemberSavePayload {
  _MemberSavePayload({
    this.name,
    this.username,
    this.avatarTone,
    this.newPassword,
  });

  final String? name;
  final String? username;
  final String? avatarTone;
  final String? newPassword;
}

class _MemberRow extends StatefulWidget {
  const _MemberRow({
    required this.member,
    required this.t,
    required this.onSave,
    this.onRemove,
  });

  final FamilyMember member;
  final Map<String, dynamic> t;
  final Future<void> Function(_MemberSavePayload payload) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  late final TextEditingController _name = TextEditingController(
    text: widget.member.name,
  );
  late final TextEditingController _username = TextEditingController(
    text: widget.member.username,
  );
  late final TextEditingController _password = TextEditingController();
  late String _tone = widget.member.avatarTone ?? 'sunrise';

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatarCircle(
                name: widget.member.name,
                photoUrl: widget.member.photoUrl,
                avatarTone: widget.member.avatarTone,
                role: widget.member.role,
                size: 40,
                showRoleBadge: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.member.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                    Text(
                      widget.member.email != null
                          ? '${t.t('manageAccounts.emailPlaceholder')}: ${widget.member.email}'
                          : t.t('manageAccounts.noEmail'),
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _name,
            hint: t.t('manageAccounts.displayNamePlaceholder'),
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _username,
            hint: t.t('manageAccounts.usernamePlaceholder'),
          ),
          const SizedBox(height: 8),
          _TonePicker(value: _tone, onChange: (v) => setState(() => _tone = v)),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _password,
            hint: t.t('manageAccounts.newPasswordPlaceholder'),
            obscure: true,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () async {
              final username = _username.text.trim().toLowerCase();
              await widget.onSave(
                _MemberSavePayload(
                  name: _name.text.trim(),
                  username: username.isEmpty ? null : username,
                  avatarTone: _tone,
                  newPassword: _password.text.isEmpty ? null : _password.text,
                ),
              );
              _password.clear();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(t.t('manageAccounts.save')),
          ),
          if (widget.onRemove != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: widget.onRemove,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(
                t.t('manageAccounts.remove'),
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: Color(0xFF6366F1),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TonePicker extends StatelessWidget {
  const _TonePicker({required this.value, required this.onChange});

  final String value;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _toneColors.entries.map((entry) {
        final active = value == entry.key;
        return GestureDetector(
          onTap: () => onChange(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE))
                  : Colors.transparent,
              border: Border.all(
                color: active
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                    color: entry.value,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: active
                        ? (isDark ? Colors.white : const Color(0xFF4C1D95))
                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InviteParentCard extends ConsumerStatefulWidget {
  const _InviteParentCard({required this.t, required this.onInvited});

  final Map<String, dynamic> t;
  final Future<void> Function() onInvited;

  @override
  ConsumerState<_InviteParentCard> createState() => _InviteParentCardState();
}

class _InviteParentCardState extends ConsumerState<_InviteParentCard> {
  bool _showForm = false;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty ||
        _username.text.isEmpty ||
        _email.text.isEmpty ||
        _password.text.isEmpty) {
      return;
    }
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .inviteParent(
            token,
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            email: _email.text.trim().toLowerCase(),
            password: _password.text,
          );
      _name.clear();
      _username.clear();
      _email.clear();
      _password.clear();
      await widget.onInvited();
      if (mounted) {
        AppToast.showSuccess(
          context,
          widget.t.t('manageAccounts.parentInvitedSuccess'),
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
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
                t.t('manageAccounts.inviteParent'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF4F4F4) : const Color(0xFF111827),
                ),
              ),
              if (!_showForm)
                OutlinedButton(
                  onPressed: () => setState(() => _showForm = true),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    t.t('manageAccounts.showForm'),
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (_showForm) ...[
            const SizedBox(height: 8),
            _FieldInput(
              controller: _name,
              hint: t.t('manageAccounts.namePlaceholder'),
            ),
            const SizedBox(height: 8),
            _FieldInput(
              controller: _username,
              hint: t.t('manageAccounts.usernamePlaceholder'),
            ),
            const SizedBox(height: 8),
            _FieldInput(
              controller: _email,
              hint: t.t('manageAccounts.emailPlaceholder'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            _FieldInput(
              controller: _password,
              hint: t.t('manageAccounts.passwordPlaceholder'),
              obscure: true,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(t.t('manageAccounts.sendInvite')),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddChildCard extends ConsumerStatefulWidget {
  const _AddChildCard({required this.t, required this.onAdded});

  final Map<String, dynamic> t;
  final Future<void> Function() onAdded;

  @override
  ConsumerState<_AddChildCard> createState() => _AddChildCardState();
}

class _AddChildCardState extends ConsumerState<_AddChildCard> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _tone = 'sunrise';

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _username.text.isEmpty || _password.text.isEmpty) {
      return;
    }
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .createChild(
            token,
            name: _name.text.trim(),
            username: _username.text.trim().toLowerCase(),
            password: _password.text,
            email: _email.text.isEmpty ? null : _email.text.trim().toLowerCase(),
            avatarTone: _tone,
          );
      _name.clear();
      _username.clear();
      _email.clear();
      _password.clear();
      setState(() => _tone = 'sunrise');
      await widget.onAdded();
      if (mounted) {
        AppToast.showSuccess(
          context,
          widget.t.t('manageAccounts.childAddedSuccess'),
        );
      }
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: isDark ? Border.all(color: const Color(0xFF334155)) : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('manageAccounts.addChild'),
            style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _name,
            hint: t.t('manageAccounts.namePlaceholder'),
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _username,
            hint: t.t('manageAccounts.usernamePlaceholder'),
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _email,
            hint: t.t('manageAccounts.optionalEmailPlaceholder'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          _FieldInput(
            controller: _password,
            hint: t.t('manageAccounts.passwordPlaceholder'),
            obscure: true,
          ),
          const SizedBox(height: 8),
          _TonePicker(value: _tone, onChange: (v) => setState(() => _tone = v)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(t.t('manageAccounts.addChild')),
          ),
        ],
      ),
    );
  }
}

class _DeleteFamilyCard extends ConsumerStatefulWidget {
  const _DeleteFamilyCard({required this.t});

  final Map<String, dynamic> t;

  @override
  ConsumerState<_DeleteFamilyCard> createState() => _DeleteFamilyCardState();
}

class _DeleteFamilyCardState extends ConsumerState<_DeleteFamilyCard> {
  bool _deleting = false;

  Future<void> _delete() async {
    final t = widget.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('manageAccounts.deleteFamilyConfirmTitle')),
        content: Text(t.t('manageAccounts.deleteFamilyConfirmMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.t('manageAccounts.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.t('manageAccounts.deleteFamily'),
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).deleteFamilyAccount(token);
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (error) {
      setState(() => _deleting = false);
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to delete family'),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.5) : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.t('manageAccounts.deleteFamilyTitle'),
            style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          Text(
            t.t('manageAccounts.deleteFamilyWarning'),
            style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _deleting ? null : _delete,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(
              _deleting
                  ? t.t('manageAccounts.deletingFamily')
                  : t.t('manageAccounts.deleteFamily'),
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
