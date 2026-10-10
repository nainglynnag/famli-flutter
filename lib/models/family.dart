import 'user.dart';

class FamilyMember {
  FamilyMember({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.email,
    this.avatarTone,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String? email;
  final String? avatarTone;
  final String? photoUrl;

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
    id: json['id'] as String,
    name: json['name'] as String,
    username: json['username'] as String,
    role: userRoleFromJson(json['role'] as String),
    email: json['email'] as String?,
    avatarTone: json['avatarTone'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );
}

class FamilyOverviewEntry {
  FamilyOverviewEntry({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.stats,
    this.avatarTone,
    this.email,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String? avatarTone;
  final String? email;
  final String? photoUrl;
  final Map<String, num> stats;

  factory FamilyOverviewEntry.fromJson(Map<String, dynamic> json) =>
      FamilyOverviewEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        username: json['username'] as String,
        role: userRoleFromJson(json['role'] as String),
        avatarTone: json['avatarTone'] as String?,
        email: json['email'] as String?,
        photoUrl: json['photoUrl'] as String?,
        stats: (json['stats'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as num),
        ),
      );
}

class FamilyStreakSettings {
  FamilyStreakSettings({
    required this.dailyStreakReward,
    required this.weeklyStreakReward,
    required this.monthlyStreakReward,
    required this.yearlyStreakReward,
  });

  final int dailyStreakReward;
  final int weeklyStreakReward;
  final int monthlyStreakReward;
  final int yearlyStreakReward;

  factory FamilyStreakSettings.fromJson(Map<String, dynamic> json) =>
      FamilyStreakSettings(
        dailyStreakReward: (json['dailyStreakReward'] as num).toInt(),
        weeklyStreakReward: (json['weeklyStreakReward'] as num).toInt(),
        monthlyStreakReward: (json['monthlyStreakReward'] as num).toInt(),
        yearlyStreakReward: (json['yearlyStreakReward'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
    'dailyStreakReward': dailyStreakReward,
    'weeklyStreakReward': weeklyStreakReward,
    'monthlyStreakReward': monthlyStreakReward,
    'yearlyStreakReward': yearlyStreakReward,
  };
}
