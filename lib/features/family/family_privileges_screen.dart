import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/translations.dart';
import '../../models/privilege.dart';
import '../../models/user.dart';
import '../../providers/api_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/i18n_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

/// Mirrors mobile/app/(app)/family/privileges.tsx.
class FamilyPrivilegesScreen extends ConsumerStatefulWidget {
  const FamilyPrivilegesScreen({super.key});

  @override
  ConsumerState<FamilyPrivilegesScreen> createState() =>
      _FamilyPrivilegesScreenState();
}

class _FamilyPrivilegesScreenState
    extends ConsumerState<FamilyPrivilegesScreen> {
  final _title = TextEditingController();
  final _cost = TextEditingController(text: '1');
  final _description = TextEditingController();
  String? _decidingRequestId;
  String? _terminatingRequestId;
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    _description.dispose();
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

  Future<void> _createPrivilege(Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    if (_title.text.trim().isEmpty) {
      _showAlert(
        t.t('privileges.titleRequiredTitle'),
        t.t('privileges.titleRequiredMessage'),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      await ref
          .read(apiClientProvider)
          .createPrivilege(
            token,
            title: _title.text.trim(),
            cost: num.tryParse(_cost.text) ?? 1,
            description: _description.text.isEmpty ? null : _description.text,
          );
      _title.clear();
      _cost.text = '1';
      _description.clear();
      ref.invalidate(privilegesProvider);
    } catch (error) {
      _showAlert(t.t('privileges.unableAdd'), error.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deletePrivilege(String privilegeId, Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    try {
      await ref.read(apiClientProvider).deletePrivilege(token, privilegeId);
      ref.invalidate(privilegesProvider);
    } catch (error) {
      _showAlert(t.t('privileges.unableRemove'), error.toString());
    }
  }

  Future<void> _decide(String requestId, bool approve, Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _decidingRequestId = requestId);
    try {
      await ref
          .read(apiClientProvider)
          .decidePrivilegeRequest(token, requestId, approve: approve);
      ref.invalidate(privilegeRequestsProvider);
      ref.invalidate(familyMembersProvider);
    } catch (error) {
      _showAlert(t.t('privileges.unableUpdateRequest'), error.toString());
    } finally {
      if (mounted) setState(() => _decidingRequestId = null);
    }
  }

  Future<void> _terminate(String requestId, Map<String, dynamic> t) async {
    final token = ref.read(authProvider).value?.token;
    if (token == null) return;
    setState(() => _terminatingRequestId = requestId);
    try {
      await ref
          .read(apiClientProvider)
          .terminatePrivilegeRequest(token, requestId);
      ref.invalidate(privilegeRequestsProvider);
      if (mounted) {
        _showAlert(
          t.t('privileges.ticketEndedTitle'),
          t.t('privileges.ticketEndedMessage'),
        );
      }
    } catch (error) {
      _showAlert(t.t('privileges.unableTerminate'), error.toString());
    } finally {
      if (mounted) setState(() => _terminatingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isParent = profile?.role == UserRole.parent;

    if (!isParent) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LightText(t.t('privileges.onlyParents')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                  ),
                  child: Text(t.t('privileges.returnHome')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final privileges = ref.watch(privilegesProvider).value ?? [];
    final requests = ref.watch(privilegeRequestsProvider).value ?? [];
    final pendingRequests = requests
        .where((r) => r.status == PrivilegeRequestStatus.pending)
        .toList();
    final activeTickets = requests
        .where((r) => r.status == PrivilegeRequestStatus.approved)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F3FF),
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('privileges.title'),
            subtitle: t.t('privileges.subtitle'),
            showBackButton: true,
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                    t.t('privileges.privilegeIdeas'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  LightText(t.t('privileges.privilegeIdeasHint')),
                  const SizedBox(height: 8),
                  if (privileges.isEmpty)
                    ref.watch(privilegesProvider).isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: SproutLoadingView(
                              message: 'Loading privilege ideas...',
                              size: SproutLoadingSize.small,
                            ),
                          )
                        : LightText(t.t('privileges.noPrivileges'))
                  else
                    ...privileges.map(
                      (privilege) => Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    privilege.title,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                  ),
                                  if (privilege.description != null)
                                    LightText(privilege.description!),
                                ],
                              ),
                            ),
                            Text(
                              '${privilege.cost} ${t.t('privileges.seedsSuffix')}',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4C1D95),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  _deletePrivilege(privilege.id, t),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                side: BorderSide(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                t.t('privileges.remove'),
                                style: TextStyle(
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('privileges.pendingRequests'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  if (pendingRequests.isEmpty)
                    LightText(t.t('privileges.noRequests'))
                  else
                    ...pendingRequests.map(
                      (request) => Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request.privilege.title,
                                        style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                      ),
                                      LightText(
                                        '${request.childName ?? t.t('privileges.unknownChild')} • ${request.cost} ${t.t('privileges.seedsSuffix')}',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    t.t('privileges.pendingLabel'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF312E81),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (request.note != null)
                              LightText('Note: ${request.note}'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton(
                                  onPressed: _decidingRequestId == request.id
                                      ? null
                                      : () => _decide(request.id, true, t),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF22C55E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _decidingRequestId == request.id
                                        ? '...'
                                        : t.t('privileges.approve'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _decidingRequestId == request.id
                                      ? null
                                      : () => _decide(request.id, false, t),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                                ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    t.t('privileges.reject'),
                                    style: TextStyle(
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.t('privileges.activeTickets'),
                        style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/privileges/history'),
                        child: Text(
                          t.t('privileges.ticketHistory'),
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (activeTickets.isEmpty)
                    LightText(t.t('privileges.noActiveTickets'))
                  else
                    ...activeTickets.map(
                      (ticket) => Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          AvatarDot(
                                            tone:
                                                ticket.childAvatarTone ??
                                                profile?.avatarTone,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            ticket.privilege.title,
                                            style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                          ),
                                        ],
                                      ),
                                      LightText(
                                        '${ticket.childName ?? t.t('privileges.unknownChild')} • ${ticket.cost} ${t.t('privileges.seedsSuffix')}',
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    t.t('privileges.approvedLabel'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (ticket.note != null)
                              LightText('Note: ${ticket.note}'),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _terminatingRequestId == ticket.id
                                  ? null
                                  : () => _terminate(ticket.id, t),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFFECACA),
                                ),
                                minimumSize: const Size.fromHeight(40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _terminatingRequestId == ticket.id
                                    ? t.t('privileges.terminating')
                                    : t.t('privileges.terminate'),
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('privileges.addPrivilege'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  LightText(t.t('privileges.addPrivilegeHint')),
                  const SizedBox(height: 10),
                  _Field(label: t.t('privileges.titleLabel'), controller: _title),
                  const SizedBox(height: 8),
                  _Field(
                    label: t.t('privileges.costLabel'),
                    controller: _cost,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _Field(
                    label: t.t('privileges.descriptionLabel'),
                    controller: _description,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _creating ? null : () => _createPrivilege(t),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_creating) ...[
                            const SproutLoadingIndicator(
                              size: SproutLoadingSize.mini,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _creating
                                ? t.t('privileges.addingPrivilege')
                                : t.t('privileges.addPrivilegeButton'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
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
        ),
      ],
    );
  }
}
