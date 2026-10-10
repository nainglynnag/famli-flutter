import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Ports api/src/utils/dates.ts. A "day" is keyed by the wall-clock date in
/// the family's timezone, but stored as a UTC-midnight [DateTime] so it can
/// be compared/queried in Firestore without carrying timezone state there.

bool _tzInitialized = false;

void _ensureTzInitialized() {
  if (_tzInitialized) return;
  tz_data.initializeTimeZones();
  _tzInitialized = true;
}

/// The IANA database the `timezone` package loads has no zone literally
/// named "UTC" (only "Etc/UTC" and the built-in [tz.UTC] constant), so
/// `getLocation('UTC')` throws even though every family defaults to that
/// exact string at registration. Route it to the constant directly.
tz.Location _resolveLocation(String timeZoneId) {
  _ensureTzInitialized();
  if (timeZoneId == 'UTC') return tz.UTC;
  return tz.getLocation(timeZoneId);
}

DateTime startOfDayInTimeZone(String timeZoneId, [DateTime? input]) {
  final location = _resolveLocation(timeZoneId);
  final zoned = tz.TZDateTime.from(input ?? DateTime.now(), location);
  return DateTime.utc(zoned.year, zoned.month, zoned.day);
}

class DayBounds {
  DayBounds(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

DayBounds dayBoundsForTimeZone(String timeZoneId, [DateTime? input]) {
  final start = startOfDayInTimeZone(timeZoneId, input);
  return DayBounds(start, start.add(const Duration(days: 1)));
}

const List<String> weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// Dart's DateTime.weekday is Mon=1..Sun=7, so Sunday needs the %7 wrap.
String weekdayKeyForTimeZone(String timeZoneId, [DateTime? input]) {
  final location = _resolveLocation(timeZoneId);
  final zoned = tz.TZDateTime.from(input ?? DateTime.now(), location);
  return weekDays[zoned.weekday % 7];
}

String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

/// A task/routine with no daysOfWeek set is active every day, matching
/// isActiveOnDay in api/src/routes/tasks.ts.
bool isActiveOnDay(List<dynamic>? daysOfWeek, String todayKey) {
  if (daysOfWeek == null || daysOfWeek.isEmpty) return true;
  return daysOfWeek.contains(todayKey);
}
