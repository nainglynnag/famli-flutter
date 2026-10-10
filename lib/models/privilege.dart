class PrivilegeDefinition {
  PrivilegeDefinition({
    required this.id,
    required this.title,
    required this.cost,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final num cost;
  final String createdAt;

  factory PrivilegeDefinition.fromJson(Map<String, dynamic> json) =>
      PrivilegeDefinition(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        cost: json['cost'] as num,
        createdAt: json['createdAt'] as String,
      );
}

enum PrivilegeRequestStatus { pending, approved, rejected, terminated }

PrivilegeRequestStatus privilegeRequestStatusFromJson(String value) {
  switch (value) {
    case 'APPROVED':
      return PrivilegeRequestStatus.approved;
    case 'REJECTED':
      return PrivilegeRequestStatus.rejected;
    case 'TERMINATED':
      return PrivilegeRequestStatus.terminated;
    default:
      return PrivilegeRequestStatus.pending;
  }
}

class PrivilegeRequestEntry {
  PrivilegeRequestEntry({
    required this.id,
    required this.privilegeId,
    required this.privilege,
    required this.status,
    required this.cost,
    required this.createdAt,
    this.childId,
    this.note,
    this.resolvedAt,
    this.childName,
    this.childAvatarTone,
  });

  final String id;
  final String privilegeId;
  final PrivilegeDefinition privilege;
  final String? childId;
  final PrivilegeRequestStatus status;
  final String? note;
  final num cost;
  final String createdAt;
  final String? resolvedAt;
  final String? childName;
  final String? childAvatarTone;

  factory PrivilegeRequestEntry.fromJson(Map<String, dynamic> json) {
    final child = json['child'] as Map<String, dynamic>?;
    return PrivilegeRequestEntry(
      id: json['id'] as String,
      privilegeId: json['privilegeId'] as String,
      privilege: PrivilegeDefinition.fromJson(
        json['privilege'] as Map<String, dynamic>,
      ),
      childId: json['childId'] as String?,
      status: privilegeRequestStatusFromJson(json['status'] as String),
      note: json['note'] as String?,
      cost: json['cost'] as num,
      createdAt: json['createdAt'] as String,
      resolvedAt: json['resolvedAt'] as String?,
      childName: json['childName'] as String? ?? child?['name'] as String?,
      childAvatarTone:
          json['childAvatarTone'] as String? ?? child?['avatarTone'] as String?,
    );
  }
}
