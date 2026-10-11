import 'dart:async';
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
import '../../widgets/app_toast.dart';
import '../../widgets/common.dart';
import '../../widgets/sticky_header.dart';

String _statusLabel(PrivilegeRequestStatus status, Map<String, dynamic> t) {
  switch (status) {
    case PrivilegeRequestStatus.approved:
      return t.t('childPrivileges.approved');
    case PrivilegeRequestStatus.rejected:
      return t.t('childPrivileges.tryAgainSoon');
    default:
      return t.t('childPrivileges.waitingForApproval');
  }
}

/// Mirrors mobile/app/(app)/privileges.tsx.
class PrivilegesScreen extends ConsumerWidget {
  const PrivilegesScreen({super.key, this.showBackButton});

  final bool? showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = ref.watch(authProvider).value?.profile;
    final isChild = profile?.role == UserRole.child;
    final seedBalanceAsync = ref.watch(childSeedBalanceProvider);
    final availableSeeds = isChild
        ? (seedBalanceAsync.value ?? profile?.progress?.seedBalance ?? 0)
        : (profile?.progress?.seedBalance ?? 0);
    final privilegesAsync = ref.watch(privilegesProvider);
    final requestsAsync = isChild
        ? ref.watch(myPrivilegeRequestsProvider)
        : const AsyncValue<List<PrivilegeRequestEntry>>.data([]);

    final privileges = privilegesAsync.value ?? [];
    final requests = requestsAsync.value ?? [];

    final latestByPrivilege = <String, PrivilegeRequestEntry>{};
    for (final request in requests) {
      if (request.status == PrivilegeRequestStatus.terminated) continue;
      final existing = latestByPrivilege[request.privilegeId];
      if (existing == null ||
          (DateTime.tryParse(request.createdAt)?.isAfter(
                DateTime.tryParse(existing.createdAt) ?? DateTime(0),
              ) ??
              false)) {
        latestByPrivilege[request.privilegeId] = request;
      }
    }

    final approvedTickets = requests
        .where((r) => r.status == PrivilegeRequestStatus.approved)
        .toList();
    final pendingRequests = requests
        .where((r) => r.status == PrivilegeRequestStatus.pending)
        .toList();
    final rejectedRequests = requests
        .where((r) => r.status == PrivilegeRequestStatus.rejected)
        .toList();
    final profileTone = profile?.avatarTone;

    Future<void> openRequestSheet() async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;

      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _RequestTicketSheet(
          availableSeeds: availableSeeds,
          familyPrivileges: privileges,
          onSubmitCustom: (title, cost, note) async {
            final authTok = ref.read(authProvider).value?.token;
            if (authTok == null) return;
            try {
              await ref.read(apiClientProvider).requestCustomPrivilege(
                    authTok,
                    title: title,
                    cost: cost,
                    note: note,
                  );
              ref.invalidate(myPrivilegeRequestsProvider);
              ref.invalidate(privilegeRequestsProvider);
              unawaited(ref.read(authProvider.notifier).refreshProfile());
              if (context.mounted) {
                AppToast.showSuccess(
                  context,
                  t.t('childPrivileges.toastRequestedSuccess'),
                );
              }
            } catch (error) {
              if (context.mounted) {
                AppToast.showError(context, error.toString());
              }
            }
          },
          onSubmitSpecific: (privilegeId) async {
            final authTok = ref.read(authProvider).value?.token;
            if (authTok == null) return;
            try {
              await ref.read(apiClientProvider).requestPrivilege(
                    authTok,
                    privilegeId,
                  );
              ref.invalidate(myPrivilegeRequestsProvider);
              ref.invalidate(privilegeRequestsProvider);
              unawaited(ref.read(authProvider.notifier).refreshProfile());
              if (context.mounted) {
                AppToast.showSuccess(
                  context,
                  t.t('childPrivileges.toastRequestedSuccess'),
                );
              }
            } catch (error) {
              if (context.mounted) {
                AppToast.showError(context, error.toString());
              }
            }
          },
        ),
      );
    }

    Future<void> handleRequest(String privilegeId) async {
      final token = ref.read(authProvider).value?.token;
      if (token == null) return;
      try {
        await ref.read(apiClientProvider).requestPrivilege(token, privilegeId);
        ref.invalidate(myPrivilegeRequestsProvider);
        ref.invalidate(privilegeRequestsProvider);
        unawaited(ref.read(authProvider.notifier).refreshProfile());
        if (context.mounted) {
          AppToast.showSuccess(
            context,
            t.t('childPrivileges.toastHangTight'),
          );
        }
      } catch (error) {
        if (context.mounted) {
          AppToast.showError(context, error.toString());
        }
      }
    }

    Widget buildPrivilegeCard(PrivilegeDefinition privilege) {
      final lastRequest = latestByPrivilege[privilege.id];
      final statusLabel =
          lastRequest != null ? _statusLabel(lastRequest.status, t) : null;
      final insufficientSeeds = availableSeeds < privilege.cost;
      final isLocked = lastRequest?.status == PrivilegeRequestStatus.pending ||
          lastRequest?.status == PrivilegeRequestStatus.approved;
      final disabled = isLocked || insufficientSeeds;
      final buttonLabel = insufficientSeeds
          ? t.t('childPrivileges.needSeeds')
          : lastRequest?.status == PrivilegeRequestStatus.approved
              ? t.t('childPrivileges.ticketReady')
              : lastRequest?.status == PrivilegeRequestStatus.pending
                  ? t.t('childPrivileges.pendingStatus')
                  : t.t('childPrivileges.requestButton');
      final num rawSeedsLeft = privilege.cost - availableSeeds;
      final seedsLeft = rawSeedsLeft > 0
          ? (rawSeedsLeft % 1 == 0 ? rawSeedsLeft.toInt() : rawSeedsLeft)
          : 0;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE0E7FF),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              privilege.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (privilege.description != null &&
                privilege.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                privilege.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${privilege.cost} ${t.t('childPrivileges.seedsSuffix')}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4C1D95),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (insufficientSeeds) ...[
              const SizedBox(height: 4),
              Text(
                '${t.t('childPrivileges.needSeeds')} ${privilege.cost} ${t.t('childPrivileges.seedsSuffix')} ($seedsLeft ${t.t('childPrivileges.leftSuffix')})',
                style: const TextStyle(
                  color: Color(0xFFEA580C),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: disabled ? null : () => handleRequest(privilege.id),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          StickyTopBar(
            title: t.t('childPrivileges.title'),
            subtitle: t.t('childPrivileges.subtitle'),
            showBackButton: showBackButton ??
                (context.canPop() ||
                    GoRouterState.of(context).matchedLocation == '/privileges'),
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            showNotificationBell: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                if (!isChild)
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('childPrivileges.headsUpTitle'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        LightText(
                          t.t('childPrivileges.headsUpChildOnly'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.t('childPrivileges.availablePrivileges'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF111827),
                          ),
                        ),
                        LightText(
                          t.t('childPrivileges.availablePrivilegesHint'),
                        ),
                        const SizedBox(height: 12),
                        if (privileges.isEmpty)
                          LightText(t.t('childPrivileges.noPrivilegesFound'))
                        else
                          Builder(
                            builder: (context) {
                              final chunks = <List<PrivilegeDefinition>>[];
                              for (var i = 0; i < privileges.length; i += 2) {
                                chunks.add(
                                  privileges.sublist(
                                    i,
                                    (i + 2 > privileges.length
                                        ? privileges.length
                                        : i + 2),
                                  ),
                                );
                              }
                              return Column(
                                children: chunks.map((chunk) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: buildPrivilegeCard(chunk[0]),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: chunk.length > 1
                                                ? buildPrivilegeCard(chunk[1])
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
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
                        Expanded(
                          child: Text(
                            t.t('childPrivileges.privilegeTickets'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: openRequestSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6C63FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 14),
                          label: Text(
                            t.t('childPrivileges.requestAction'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => context.go('/privileges/history'),
                          child: Text(
                            t.t('childPrivileges.historyAction'),
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.t('childPrivileges.privilegeTicketsSubtitle'),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (approvedTickets.isEmpty)
                      LightText(
                        t.t('childPrivileges.noTicketsYet'),
                      )
                    else
                      ...approvedTickets.map(
                        (ticket) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF78350F).withAlpha(80)
                                : const Color(0xFFFFFBEB),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFFFDE68A),
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AvatarDot(
                                    tone: ticket.childAvatarTone ?? profileTone,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ticket.childName ?? t.t('childPrivileges.you'),
                                    style: TextStyle(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFB45309),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                ticket.privilege.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : const Color(0xFF92400E),
                                ),
                              ),
                              Text(
                                '${ticket.cost} ${t.t('childPrivileges.seedsSuffix')}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFCA8A04),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${t.t('childPrivileges.approvedOn')} ${_formatDate(ticket.resolvedAt ?? ticket.createdAt)}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFB45309),
                                  fontSize: 12,
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
                      t.t('childPrivileges.pendingRequests'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF111827),
                      ),
                    ),
                    if (pendingRequests.isEmpty)
                      LightText(
                        t.t('childPrivileges.noPendingRequests'),
                      )
                    else
                      ...pendingRequests.map(
                        (request) => _PendingRow(
                          title: request.privilege.title,
                          subtitle: '${request.cost} ${t.t('childPrivileges.seedsSuffix')}',
                          status: t.t('childPrivileges.waiting'),
                          statusColor: const Color(0xFF6C63FF),
                          tone: request.childAvatarTone ?? profileTone,
                        ),
                      ),
                  ],
                ),
              ),
              if (rejectedRequests.isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.t('childPrivileges.recentlyReviewed'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF111827),
                        ),
                      ),
                      ...rejectedRequests.map(
                        (request) => _PendingRow(
                          title: request.privilege.title,
                          subtitle: t.t('childPrivileges.tryRequestingAgain'),
                          status: t.t('childPrivileges.rejected'),
                          statusColor: const Color(0xFFDC2626),
                          tone: request.childAvatarTone ?? profileTone,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ],
  ),
);
}
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.tone,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String? tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : null,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AvatarDot(tone: tone, size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                LightText(subtitle),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RequestTicketSheet extends ConsumerStatefulWidget {
  const _RequestTicketSheet({
    required this.availableSeeds,
    required this.familyPrivileges,
    required this.onSubmitCustom,
    required this.onSubmitSpecific,
  });

  final num availableSeeds;
  final List<PrivilegeDefinition> familyPrivileges;
  final Future<void> Function(String title, num cost, String? note) onSubmitCustom;
  final Future<void> Function(String privilegeId) onSubmitSpecific;

  @override
  ConsumerState<_RequestTicketSheet> createState() => _RequestTicketSheetState();
}

class _RequestTicketSheetState extends ConsumerState<_RequestTicketSheet> {
  bool _isCustom = true;
  final _titleController = TextEditingController();
  final _costController = TextEditingController(text: '10');
  final _noteController = TextEditingController();
  PrivilegeDefinition? _selectedPrivilege;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.familyPrivileges.isNotEmpty) {
      _selectedPrivilege = widget.familyPrivileges.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cost = _isCustom
        ? (num.tryParse(_costController.text.trim()) ?? 0)
        : (_selectedPrivilege?.cost ?? 0);
    final hasEnoughSeeds = widget.availableSeeds >= cost && cost > 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t.t('childPrivileges.sheetTitle'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✨ ${widget.availableSeeds} ${t.t('childPrivileges.seedsSuffix')}',
                      style: const TextStyle(
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.t('childPrivileges.sheetSubtitle'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.familyPrivileges.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(t.t('childPrivileges.customRequestChip'))),
                        selected: _isCustom,
                        onSelected: (val) {
                          if (val) setState(() => _isCustom = true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(t.t('childPrivileges.familyPrivilegesChip'))),
                        selected: !_isCustom,
                        onSelected: (val) {
                          if (val) setState(() => _isCustom = false);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (_isCustom) ...[
                Text(
                  t.t('childPrivileges.whatToRequest'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: t.t('childPrivileges.whatToRequestPlaceholder'),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Text(
                  t.t('childPrivileges.seedsToSpend'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: '10',
                    prefixIcon: const Icon(Icons.token_rounded, color: Color(0xFFF59E0B)),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Text(
                  t.t('childPrivileges.noteForParent'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: t.t('childPrivileges.noteForParentPlaceholder'),
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  t.t('childPrivileges.selectPrivilege'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PrivilegeDefinition>(
                      value: _selectedPrivilege,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                      items: widget.familyPrivileges.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.title} (${p.cost} ${t.t('childPrivileges.seedsSuffix')})',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (p) => setState(() => _selectedPrivilege = p),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (!hasEnoughSeeds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${t.t('childPrivileges.notEnoughSeedsWarning')} (${widget.availableSeeds}/$cost ${t.t('childPrivileges.seedsSuffix')})',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_submitting ||
                          !hasEnoughSeeds ||
                          (_isCustom && _titleController.text.trim().isEmpty))
                      ? null
                      : () async {
                          setState(() => _submitting = true);
                          try {
                            if (_isCustom) {
                              await widget.onSubmitCustom(
                                _titleController.text.trim(),
                                cost,
                                _noteController.text.trim().isEmpty
                                    ? null
                                    : _noteController.text.trim(),
                              );
                            } else if (_selectedPrivilege != null) {
                              await widget.onSubmitSpecific(
                                _selectedPrivilege!.id,
                              );
                            }
                            if (context.mounted) Navigator.of(context).pop();
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _submitting
                      ? const SproutLoadingIndicator(
                          size: SproutLoadingSize.mini,
                          color: Colors.white,
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _submitting
                        ? t.t('childPrivileges.sending')
                        : t.t('childPrivileges.sendRequest'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

String _formatDate(String? value) {
  if (value == null) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return '';
  return '${date.month}/${date.day}/${date.year}';
}
