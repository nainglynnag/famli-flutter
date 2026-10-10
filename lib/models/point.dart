class PointEntryChild {
  PointEntryChild({
    required this.id,
    required this.name,
    this.username,
    this.avatarTone,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarTone;

  factory PointEntryChild.fromJson(Map<String, dynamic> json) =>
      PointEntryChild(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String?,
        avatarTone: json['avatarTone'] as String?,
      );
}

class PointEntryCreatedBy {
  PointEntryCreatedBy({required this.id, required this.name});

  final String id;
  final String name;

  factory PointEntryCreatedBy.fromJson(Map<String, dynamic> json) =>
      PointEntryCreatedBy(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

enum PointEntryType { gift, penalty }

PointEntryType pointEntryTypeFromJson(String value) =>
    value == 'GIFT' ? PointEntryType.gift : PointEntryType.penalty;

String pointEntryTypeToJson(PointEntryType type) =>
    type == PointEntryType.gift ? 'GIFT' : 'PENALTY';

class PointEntry {
  PointEntry({
    required this.id,
    required this.type,
    required this.points,
    required this.amount,
    required this.createdAt,
    this.note,
    this.child,
    this.createdBy,
  });

  final String id;
  final PointEntryType type;
  final num points;
  final num amount;
  final String? note;
  final String createdAt;
  final PointEntryChild? child;
  final PointEntryCreatedBy? createdBy;

  factory PointEntry.fromJson(Map<String, dynamic> json) => PointEntry(
    id: json['id'] as String,
    type: pointEntryTypeFromJson(json['type'] as String),
    points: json['points'] as num,
    amount: json['amount'] as num,
    note: json['note'] as String?,
    createdAt: json['createdAt'] as String,
    child: json['child'] != null
        ? PointEntryChild.fromJson(json['child'] as Map<String, dynamic>)
        : null,
    createdBy: json['createdBy'] != null
        ? PointEntryCreatedBy.fromJson(
            json['createdBy'] as Map<String, dynamic>,
          )
        : null,
  );
}
