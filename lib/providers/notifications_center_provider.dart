import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../core/secure_storage.dart';
import '../models/privilege.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'data_providers.dart';

enum NotificationType {
  assignment,
  pointsAdjustment,
  reward,
  privilegeDecision,
  childRequest,
  taskCompleted,
  reminder,
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.route,
    this.childAvatarTone,
    this.childPhotoUrl,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final bool isRead;
  final String? route;
  final String? childAvatarTone;
  final String? childPhotoUrl;

  AppNotificationItem copyWith({bool? isRead}) => AppNotificationItem(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        type: type,
        isRead: isRead ?? this.isRead,
        route: route,
        childAvatarTone: childAvatarTone,
        childPhotoUrl: childPhotoUrl,
      );
}

class NotificationsCenterState {
  const NotificationsCenterState({
    this.items = const [],
    this.readIds = const {},
  });

  final List<AppNotificationItem> items;
  final Set<String> readIds;

  int get unreadCount => items.where((item) => !readIds.contains(item.id)).length;
}

class NotificationsCenterNotifier extends Notifier<NotificationsCenterState> {
  final SecureStorage _storage = SecureStorage();

  @override
  NotificationsCenterState build() {
    _hydrateReadIds();
    return const NotificationsCenterState();
  }

  Future<void> _hydrateReadIds() async {
    final raw = await _storage.read(Env.readNotificationsStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        state = NotificationsCenterState(
          items: state.items,
          readIds: list.map((e) => e.toString()).toSet(),
        );
      } catch (_) {}
    }
  }

  Future<void> markAsRead(String id) async {
    final updated = Set<String>.from(state.readIds)..add(id);
    state = NotificationsCenterState(items: state.items, readIds: updated);
    await _storage.write(
      Env.readNotificationsStorageKey,
      jsonEncode(updated.toList()),
    );
  }

  Future<void> markAllAsRead([Iterable<String>? ids]) async {
    final toAdd = ids ?? state.items.map((i) => i.id);
    final updated = Set<String>.from(state.readIds)..addAll(toAdd);
    state = NotificationsCenterState(items: state.items, readIds: updated);
    await _storage.write(
      Env.readNotificationsStorageKey,
      jsonEncode(updated.toList()),
    );
  }

  void updateItems(List<AppNotificationItem> items) {
    state = NotificationsCenterState(items: items, readIds: state.readIds);
  }
}

final notificationsCenterNotifierProvider =
    NotifierProvider<NotificationsCenterNotifier, NotificationsCenterState>(
  NotificationsCenterNotifier.new,
);

final notificationsCenterProvider = notificationsCenterNotifierProvider;

/// Aggregates recent activity items based on user role (Parent vs Child)
final aggregatedNotificationsProvider =
    Provider.autoDispose<List<AppNotificationItem>>((ref) {
  final auth = ref.watch(authProvider).value;
  final profile = auth?.profile;
  if (profile == null) return [];

  final isParent = profile.role == UserRole.parent;
  final centerState = ref.watch(notificationsCenterNotifierProvider);
  final items = <AppNotificationItem>[];

  if (isParent) {
    // 1. Task completions by children
    final history = ref.watch(taskHistoryProvider).value ?? [];
    for (final h in history.take(15)) {
      if (h.status == 'COMPLETED') {
        final date = DateTime.tryParse(h.date) ?? DateTime.now();
        items.add(AppNotificationItem(
          id: 'comp_${h.id}_${h.date}',
          title: 'Task Completed! 🎉',
          body:
              '${h.childName ?? "Child"} completed "${h.taskTitle}" (+${h.points ?? 0} seeds)',
          createdAt: date,
          type: NotificationType.taskCompleted,
          isRead: centerState.readIds.contains('comp_${h.id}_${h.date}'),
          route: '/history',
          childAvatarTone: h.childAvatarTone,
        ));
      }
    }

    // 2. Privilege requests from children
    final requests = ref.watch(privilegeRequestsProvider).value ?? [];
    for (final req in requests.take(15)) {
      final date = DateTime.tryParse(req.createdAt) ?? DateTime.now();
      final isPending = req.status == PrivilegeRequestStatus.pending;
      items.add(AppNotificationItem(
        id: 'req_${req.id}',
        title: isPending
            ? 'New Privilege Request 🌿'
            : 'Privilege Request (${req.status.name})',
        body:
            '${req.childName ?? "Child"} requested "${req.privilege.title}" (${req.cost} seeds)',
        createdAt: date,
        type: NotificationType.childRequest,
        isRead: centerState.readIds.contains('req_${req.id}'),
        route: '/family/privileges',
        childAvatarTone: req.childAvatarTone,
      ));
    }

    // 3. Reminder to check missing tasks & routines
    final overview = ref.watch(familyOverviewProvider).value ?? [];
    int totalIncomplete = 0;
    final incompleteChildren = <String>[];
    for (final child in overview) {
      final pendingCount = (child.stats['pendingTasks']?.toInt() ?? 0);
      if (pendingCount > 0) {
        totalIncomplete += pendingCount;
        incompleteChildren.add(child.name);
      }
    }
    if (totalIncomplete > 0) {
      items.add(AppNotificationItem(
        id: 'missing_tasks_today_${DateTime.now().day}',
        title: 'Check Missing Tasks 📋',
        body:
            '$totalIncomplete open task(s) remaining today for ${incompleteChildren.join(", ")}.',
        createdAt: DateTime.now(),
        type: NotificationType.reminder,
        isRead: centerState.readIds
            .contains('missing_tasks_today_${DateTime.now().day}'),
        route: '/family',
      ));
    }
  } else {
    // ---- CHILD NOTIFICATIONS ----
    // 1. Tasks & routines assigned
    final tasks = ref.watch(tasksProvider).value ?? [];
    for (final task in tasks.take(15)) {
      final isCompleted = task.status == 'COMPLETED';
      items.add(AppNotificationItem(
        id: 'task_${task.id}',
        title: task.routineName != null ? 'Routine Task: ${task.routineName}' : 'Task Assigned ✨',
        body: '${task.title} • ${task.points} seeds ${isCompleted ? "(Completed)" : ""}',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        type: NotificationType.assignment,
        isRead: centerState.readIds.contains('task_${task.id}'),
        route: '/tasks',
      ));
    }

    // 2. Receiving Gifts & Penalty
    final points = ref.watch(todayPointEntriesProvider).value ?? [];
    for (final entry in points) {
      final date = DateTime.tryParse(entry.createdAt) ?? DateTime.now();
      final isGift = entry.points >= 0;
      items.add(AppNotificationItem(
        id: 'point_${entry.id}',
        title: isGift ? 'Gift Received! 🎁' : 'Point Adjustment ⚠️',
        body: '${entry.points > 0 ? "+" : ""}${entry.points} seeds${entry.note != null ? " • ${entry.note}" : ""}',
        createdAt: date,
        type: NotificationType.pointsAdjustment,
        isRead: centerState.readIds.contains('point_${entry.id}'),
        route: '/points',
      ));
    }

    // 3. Decisions on privilege tickets
    final myRequests = ref.watch(myPrivilegeRequestsProvider).value ?? [];
    for (final req in myRequests.take(15)) {
      final date = DateTime.tryParse(req.resolvedAt ?? req.createdAt) ?? DateTime.now();
      if (req.status == PrivilegeRequestStatus.approved) {
        items.add(AppNotificationItem(
          id: 'priv_dec_${req.id}',
          title: 'Ticket Approved! 🎟️',
          body: 'Your parent approved "${req.privilege.title}"! Enjoy your reward.',
          createdAt: date,
          type: NotificationType.privilegeDecision,
          isRead: centerState.readIds.contains('priv_dec_${req.id}'),
          route: '/family',
        ));
      } else if (req.status == PrivilegeRequestStatus.rejected) {
        items.add(AppNotificationItem(
          id: 'priv_dec_${req.id}',
          title: 'Request Update 💭',
          body: 'Request for "${req.privilege.title}" was not approved this time.',
          createdAt: date,
          type: NotificationType.privilegeDecision,
          isRead: centerState.readIds.contains('priv_dec_${req.id}'),
          route: '/family',
        ));
      }
    }

    // 4. Streak rewards
    final streak = profile.progress?.streak ?? 0;
    if (streak > 0) {
      items.add(AppNotificationItem(
        id: 'streak_$streak',
        title: 'Streak Active! 🔥',
        body: 'You are on a $streak-day streak! Keep up the momentum for streak rewards.',
        createdAt: DateTime.now(),
        type: NotificationType.reward,
        isRead: centerState.readIds.contains('streak_$streak'),
        route: '/home',
      ));
    }
  }

  // Sort descending by creation date
  items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
});
