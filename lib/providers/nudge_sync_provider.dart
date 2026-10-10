import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/nudges.dart';
import '../core/notifications.dart';
import '../models/nudge.dart';
import '../models/user.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Mirrors mobile/src/context/NudgeSync.tsx: (re)schedules the child's local
/// nudge notifications from server-driven settings whenever auth state
/// changes, falling back to the default nudge templates when none are set.
final nudgeSyncProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authProvider).value;
  final token = authState?.token;
  final profile = authState?.profile;

  if (token == null || profile?.role != UserRole.child) {
    await NotificationService.instance.cancelNudgeNotifications();
    return;
  }

  final granted = await NotificationService.instance.ensurePermissions();
  if (!granted) return;

  List<NudgeSetting> nudges;
  try {
    nudges = await ref.watch(apiClientProvider).fetchNudges(token);
  } catch (_) {
    nudges = [];
  }

  final resolved = nudges.isNotEmpty
      ? nudges
      : defaultNudges
            .map(
              (template) => NudgeSetting(
                id: 'default-${template.type}',
                childId: profile!.id,
                type: template.type,
                label: template.label,
                time: template.time,
                enabled: true,
                updatedAt: DateTime.now().toIso8601String(),
                message: template.message,
              ),
            )
            .toList();

  await NotificationService.instance.scheduleNudges(
    resolved
        .map(
          (entry) => SchedulableNudge(
            type: entry.type,
            label: entry.label,
            time: entry.time,
            enabled: entry.enabled,
            message: entry.message,
          ),
        )
        .toList(),
  );
});
