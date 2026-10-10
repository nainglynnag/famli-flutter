class TaskAssignment {
  TaskAssignment({
    required this.childId,
    required this.childName,
    required this.status,
    this.childAvatarTone,
    this.childPhotoUrl,
    this.isApplicableToday = true,
  });

  final String childId;
  final String childName;
  final String? childAvatarTone;
  final String? childPhotoUrl;
  final String status;
  final bool isApplicableToday;

  factory TaskAssignment.fromJson(Map<String, dynamic> json) => TaskAssignment(
    childId: json['childId'] as String,
    childName: json['childName'] as String,
    childAvatarTone: json['childAvatarTone'] as String?,
    childPhotoUrl: json['childPhotoUrl'] as String?,
    status: json['status'] as String,
    isApplicableToday: json['isApplicableToday'] as bool? ?? true,
  );
}

/// Mirrors the TS union `ChildTaskSummary | ParentTaskSummary` returned by
/// GET /tasks: a child sees their own task fields (icon/reminderStyle/
/// frequency/status), a parent sees `assignments` instead. Both variants
/// are folded into one model with nullable fields for whichever half
/// doesn't apply to the caller's role.
class TaskSummary {
  TaskSummary({
    required this.id,
    required this.title,
    required this.points,
    this.icon,
    this.reminderStyle,
    this.frequency,
    this.status,
    this.routineName,
    this.routineId,
    this.daysOfWeek,
    this.assignments,
    this.dueAt,
  });

  final String id;
  final String title;
  final String? icon;
  final String? reminderStyle;
  final num points;
  final String? frequency;
  final String? status;
  final String? routineName;
  final String? routineId;
  final List<String>? daysOfWeek;
  final List<TaskAssignment>? assignments;
  final DateTime? dueAt;

  bool get isParentView => assignments != null;

  factory TaskSummary.fromJson(Map<String, dynamic> json) => TaskSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    points: json['points'] as num,
    icon: json['icon'] as String?,
    reminderStyle: json['reminderStyle'] as String?,
    frequency: json['frequency'] as String?,
    status: json['status'] as String?,
    routineName: json['routineName'] as String?,
    routineId: json['routineId'] as String?,
    daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
    assignments: (json['assignments'] as List<dynamic>?)
        ?.map((e) => TaskAssignment.fromJson(e as Map<String, dynamic>))
        .toList(),
    dueAt: _parseDateTime(json['dueAt']),
  );
}

class TaskCompletion {
  TaskCompletion({
    required this.id,
    required this.childId,
    required this.childName,
    required this.status,
    required this.date,
    this.childAvatarTone,
    this.childPhotoUrl,
  });

  final String id;
  final String childId;
  final String childName;
  final String? childAvatarTone;
  final String? childPhotoUrl;
  final String status;
  final String date;

  factory TaskCompletion.fromJson(Map<String, dynamic> json) => TaskCompletion(
    id: json['id'] as String,
    childId: json['childId'] as String,
    childName: json['childName'] as String,
    childAvatarTone: json['childAvatarTone'] as String?,
    childPhotoUrl: json['childPhotoUrl'] as String?,
    status: json['status'] as String,
    date: json['date'] as String,
  );
}

class TaskDetail {
  TaskDetail({
    required this.id,
    required this.title,
    required this.points,
    required this.reminderStyle,
    required this.frequency,
    required this.assignments,
    required this.completions,
    this.description,
    this.icon,
    this.daysOfWeek,
    this.routineName,
    this.dueAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? icon;
  final num points;
  final String reminderStyle;
  final String frequency;
  final List<String>? daysOfWeek;
  final String? routineName;
  final List<TaskAssignment> assignments;
  final List<TaskCompletion> completions;
  final DateTime? dueAt;

  factory TaskDetail.fromJson(Map<String, dynamic> json) => TaskDetail(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    icon: json['icon'] as String?,
    points: json['points'] as num,
    reminderStyle: json['reminderStyle'] as String,
    frequency: json['frequency'] as String,
    daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
    routineName: json['routineName'] as String?,
    assignments: (json['assignments'] as List<dynamic>? ?? [])
        .map((e) => TaskAssignment.fromJson(e as Map<String, dynamic>))
        .toList(),
    completions: (json['completions'] as List<dynamic>? ?? [])
        .map((e) => TaskCompletion.fromJson(e as Map<String, dynamic>))
        .toList(),
    dueAt: _parseDateTime(json['dueAt']),
  );
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic dynamicVal = value;
    return dynamicVal.toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

class TaskHistoryEntry {
  TaskHistoryEntry({
    required this.id,
    required this.taskTitle,
    required this.status,
    required this.date,
    this.childName,
    this.points,
    this.childAvatarTone,
  });

  final String id;
  final String taskTitle;
  final String? childName;
  final num? points;
  final String? childAvatarTone;
  final String status;
  final String date;

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TaskHistoryEntry(
        id: json['id'] as String,
        taskTitle: json['taskTitle'] as String,
        childName: json['childName'] as String?,
        points: json['points'] as num?,
        childAvatarTone: json['childAvatarTone'] as String?,
        status: json['status'] as String,
        date: json['date'] as String,
      );
}
