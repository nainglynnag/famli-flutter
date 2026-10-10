class RoutineTemplateItem {
  RoutineTemplateItem({
    required this.id,
    required this.title,
    required this.points,
    required this.reminderStyle,
    this.description,
    this.icon,
  });

  final String id;
  final String title;
  final String? description;
  final String? icon;
  final num points;
  final String reminderStyle;

  factory RoutineTemplateItem.fromJson(Map<String, dynamic> json) =>
      RoutineTemplateItem(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        points: json['points'] as num,
        reminderStyle: json['reminderStyle'] as String,
      );
}

class RoutineTemplateAssignment {
  RoutineTemplateAssignment({
    required this.id,
    required this.childId,
    required this.childName,
    this.childAvatarTone,
    this.childPhotoUrl,
  });

  final String id;
  final String childId;
  final String childName;
  final String? childAvatarTone;
  final String? childPhotoUrl;

  factory RoutineTemplateAssignment.fromJson(Map<String, dynamic> json) =>
      RoutineTemplateAssignment(
        id: json['id'] as String,
        childId: json['childId'] as String,
        childName: json['childName'] as String,
        childAvatarTone: json['childAvatarTone'] as String?,
        childPhotoUrl: json['childPhotoUrl'] as String?,
      );
}

class RoutineTemplate {
  RoutineTemplate({
    required this.id,
    required this.name,
    required this.frequency,
    required this.items,
    this.description,
    this.daysOfWeek,
    this.rewardNote,
    this.assignments,
  });

  final String id;
  final String name;
  final String? description;
  final String frequency;
  final List<String>? daysOfWeek;
  final String? rewardNote;
  final List<RoutineTemplateItem> items;
  final List<RoutineTemplateAssignment>? assignments;

  factory RoutineTemplate.fromJson(Map<String, dynamic> json) =>
      RoutineTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        frequency: json['frequency'] as String,
        daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
        rewardNote: json['rewardNote'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => RoutineTemplateItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        assignments: (json['assignments'] as List<dynamic>?)
            ?.map(
              (e) =>
                  RoutineTemplateAssignment.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}
