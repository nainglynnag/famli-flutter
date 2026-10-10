class NudgeSetting {
  NudgeSetting({
    required this.id,
    required this.childId,
    required this.type,
    required this.label,
    required this.time,
    required this.enabled,
    required this.updatedAt,
    this.childName,
    this.childAvatarTone,
    this.message,
  });

  final String id;
  final String childId;
  final String? childName;
  final String? childAvatarTone;
  final String type;
  final String label;
  final String time;
  final String? message;
  final bool enabled;
  final String updatedAt;

  factory NudgeSetting.fromJson(Map<String, dynamic> json) => NudgeSetting(
    id: json['id'] as String,
    childId: json['childId'] as String,
    childName: json['childName'] as String?,
    childAvatarTone: json['childAvatarTone'] as String?,
    type: json['type'] as String,
    label: json['label'] as String,
    time: json['time'] as String,
    message: json['message'] as String?,
    enabled: json['enabled'] as bool,
    updatedAt: json['updatedAt'] as String,
  );
}

class NudgeUpdateItem {
  NudgeUpdateItem({
    required this.type,
    required this.time,
    required this.enabled,
    this.message,
  });

  final String type;
  final String time;
  final bool enabled;
  final String? message;

  Map<String, dynamic> toJson() => {
    'type': type,
    'time': time,
    'enabled': enabled,
    if (message != null) 'message': message,
  };
}
