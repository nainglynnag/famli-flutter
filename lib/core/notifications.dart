import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../constants/nudges.dart';

class SchedulableNudge {
  const SchedulableNudge({
    required this.type,
    required this.label,
    required this.time,
    required this.enabled,
    this.message,
  });

  final String type;
  final String label;
  final String time;
  final bool enabled;
  final String? message;
}

/// Mirrors mobile/src/services/notifications.ts: schedules one daily local
/// notification per enabled nudge, tagged so they can be cleared and
/// re-scheduled as a batch whenever the server-driven nudge list changes.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'nudges';
  static const _channelName = 'Famli nudges';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// dart:io's Platform throws unconditionally on web, and
  /// flutter_local_notifications has a different, browser-permission-based
  /// model there anyway. Nudges are local-only by design (see
  /// FIREBASE_MIGRATION_PLAN.md §2) — every public method below no-ops on
  /// web rather than attempting a lesser version of scheduling.
  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {
      // Fall back to whatever default the timezone package ships with.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.defaultImportance,
            ),
          );
    }

    _initialized = true;
  }

  Future<bool> ensurePermissions() async {
    if (kIsWeb) return false;
    await _ensureInitialized();

    if (Platform.isIOS || Platform.isMacOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  int _idFor(String type) => type.hashCode & 0x7fffffff;

  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await _plugin.show(
      id: _idFor('test'),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancelNudgeNotifications() async {
    if (kIsWeb) return;
    await _ensureInitialized();
    for (final template in defaultNudges) {
      await _plugin.cancel(id: _idFor(template.type));
    }
  }

  Future<void> scheduleNudges(List<SchedulableNudge> nudges) async {
    if (kIsWeb) return;
    await _ensureInitialized();
    await cancelNudgeNotifications();

    for (final nudge in nudges) {
      if (!nudge.enabled) continue;
      final match = RegExp(r'^(\d{1,2}):([0-5]\d)$').firstMatch(nudge.time);
      if (match == null) continue;
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour > 23) continue;

      final template = nudgeTemplateFor(nudge.type);
      final body =
          nudge.message ?? template?.message ?? 'Friendly reminder from Famli.';
      final title = nudge.label.isNotEmpty
          ? nudge.label
          : (template?.label ?? 'Famli');

      await _plugin.zonedSchedule(
        id: _idFor(nudge.type),
        title: title,
        body: body,
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(_channelId, _channelName),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
