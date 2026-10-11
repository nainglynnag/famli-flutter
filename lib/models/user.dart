class UserProgress {
  UserProgress({required this.seedBalance, required this.streak});

  final int seedBalance;
  final int streak;

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
    seedBalance: (json['seedBalance'] as num?)?.toInt() ?? 0,
    streak: (json['streak'] as num?)?.toInt() ?? 0,
  );
}

class UserFamily {
  UserFamily({required this.id, required this.name, this.timezone});

  final String id;
  final String name;
  final String? timezone;

  factory UserFamily.fromJson(Map<String, dynamic> json) => UserFamily(
    id: json['id'] as String,
    name: json['name'] as String,
    timezone: json['timezone'] as String?,
  );
}

enum UserRole { parent, child }

UserRole userRoleFromJson(String value) =>
    value == 'PARENT' ? UserRole.parent : UserRole.child;

String userRoleToJson(UserRole role) =>
    role == UserRole.parent ? 'PARENT' : 'CHILD';

class UserPreferences {
  const UserPreferences({this.themeMode, this.language});

  final String? themeMode;
  final String? language;

  factory UserPreferences.fromJson(Map<String, dynamic> json) => UserPreferences(
    themeMode: json['themeMode'] as String?,
    language: json['language'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (themeMode != null) 'themeMode': themeMode,
    if (language != null) 'language': language,
  };
}

class UserSummary {
  UserSummary({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.email,
    this.avatarTone,
    this.photoUrl,
    this.familyId,
    this.family,
    this.progress,
    this.preferences,
  });

  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String? email;
  final String? avatarTone;
  final String? photoUrl;
  final String? familyId;
  final UserFamily? family;
  final UserProgress? progress;
  final UserPreferences? preferences;

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    final prefsJson = json['preferences'] as Map<String, dynamic>?;
    final preferences = prefsJson != null
        ? UserPreferences.fromJson(prefsJson)
        : (json['themeMode'] != null || json['language'] != null)
            ? UserPreferences(
                themeMode: json['themeMode'] as String?,
                language: json['language'] as String?,
              )
            : null;

    return UserSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      role: userRoleFromJson(json['role'] as String),
      email: json['email'] as String?,
      avatarTone: json['avatarTone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      familyId: json['familyId'] as String?,
      family: json['family'] != null
          ? UserFamily.fromJson(json['family'] as Map<String, dynamic>)
          : null,
      progress: json['progress'] != null
          ? UserProgress.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
      preferences: preferences,
    );
  }
}

class LoginResponse {
  LoginResponse({required this.token, required this.user});

  final String token;
  final UserSummary user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class RegisterParentPayload {
  RegisterParentPayload({
    required this.familyName,
    required this.parent,
    this.timezone,
  });

  final String familyName;
  final RegisterParentDetails parent;
  final String? timezone;

  Map<String, dynamic> toJson() => {
    'familyName': familyName,
    'parent': parent.toJson(),
    if (timezone != null) 'timezone': timezone,
  };
}

class RegisterParentDetails {
  RegisterParentDetails({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
  });

  final String name;
  final String username;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'name': name,
    'username': username,
    'email': email,
    'password': password,
  };
}

class RegisterParentResponse {
  RegisterParentResponse({required this.token, required this.parent});

  final String token;
  final UserSummary parent;

  factory RegisterParentResponse.fromJson(Map<String, dynamic> json) =>
      RegisterParentResponse(
        token: json['token'] as String,
        parent: UserSummary.fromJson(json['parent'] as Map<String, dynamic>),
      );
}
