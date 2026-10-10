import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../config/env.dart';
import '../models/family.dart';
import '../models/nudge.dart';
import '../models/point.dart';
import '../models/privilege.dart';
import '../models/routine.dart';
import '../models/task.dart';
import '../models/user.dart';
import 'api_exception.dart';

/// Mirrors mobile/src/services/api.ts: one client, one request() wrapper,
/// a typed method per endpoint. Every method takes `token` explicitly,
/// same as the TS functions, so callers (Riverpod providers) control auth.
class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));

  final Dio _dio;
  String? _cachedTimezone;

  Future<String?> _timezone() async {
    if (_cachedTimezone != null) return _cachedTimezone;
    try {
      _cachedTimezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      _cachedTimezone = null;
    }
    return _cachedTimezone;
  }

  Future<T> _request<T>(
    String path, {
    String method = 'GET',
    Object? body,
    String? token,
    required T Function(dynamic data) parse,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final tz = await _timezone();
    if (tz != null) {
      headers['X-Timezone'] = tz;
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(method: method, headers: headers),
      );
      return parse(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = (data is Map && data['error'] is String)
          ? data['error'] as String
          : 'Something went wrong';
      throw ApiException(message);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      (data as Map).cast<String, dynamic>();

  List<Map<String, dynamic>> _asList(dynamic data) =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

  // ---- Auth ----

  Future<LoginResponse> login(String identifier, String password) => _request(
    '/auth/login',
    method: 'POST',
    body: {'identifier': identifier, 'password': password},
    parse: (data) => LoginResponse.fromJson(_asMap(data)),
  );

  Future<RegisterParentResponse> registerParent(
    RegisterParentPayload payload,
  ) => _request(
    '/auth/register-parent',
    method: 'POST',
    body: payload.toJson(),
    parse: (data) => RegisterParentResponse.fromJson(_asMap(data)),
  );

  Future<UserSummary> fetchProfile(String token) => _request(
    '/auth/me',
    token: token,
    parse: (data) => UserSummary.fromJson(_asMap(data)),
  );

  Future<UserSummary> updateProfile(
    String token, {
    String? name,
    String? avatarTone,
    String? photoUrl,
    String? currentPassword,
    String? newPassword,
    String? familyTimezone,
  }) => _request(
    '/auth/me',
    method: 'PATCH',
    token: token,
    body: {
      'name': ?name,
      'avatarTone': ?avatarTone,
      'photoUrl': ?photoUrl,
      'currentPassword': ?currentPassword,
      'newPassword': ?newPassword,
      'familyTimezone': ?familyTimezone,
    },
    parse: (data) => UserSummary.fromJson(_asMap(data)),
  );

  Future<List<FamilyMember>> fetchFamilyMembers(String token) => _request(
    '/auth/family/members',
    token: token,
    parse: (data) => _asList(data).map(FamilyMember.fromJson).toList(),
  );

  Future<FamilyMember> createChild(
    String token, {
    required String name,
    required String username,
    required String password,
    String? email,
    String? avatarTone,
  }) => _request(
    '/auth/add-child',
    method: 'POST',
    token: token,
    body: {
      'name': name,
      'username': username,
      'password': password,
      'email': ?email,
      'avatarTone': ?avatarTone,
    },
    parse: (data) => FamilyMember.fromJson(_asMap(_asMap(data)['child'])),
  );

  Future<FamilyMember> inviteParent(
    String token, {
    required String name,
    required String username,
    required String email,
    required String password,
  }) => _request(
    '/auth/family/parents',
    method: 'POST',
    token: token,
    body: {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
    },
    parse: (data) => FamilyMember.fromJson(_asMap(_asMap(data)['parent'])),
  );

  Future<FamilyMember> updateFamilyMember(
    String token,
    String userId, {
    String? name,
    String? username,
    String? avatarTone,
    String? newPassword,
  }) => _request(
    '/auth/family/members/$userId',
    method: 'PATCH',
    token: token,
    body: {
      'name': ?name,
      'username': ?username,
      'avatarTone': ?avatarTone,
      'newPassword': ?newPassword,
    },
    parse: (data) => FamilyMember.fromJson(_asMap(data)),
  );

  Future<void> deleteFamilyMember(String token, String userId) => _request(
    '/auth/family/members/$userId',
    method: 'DELETE',
    token: token,
    parse: (_) {},
  );

  Future<List<FamilyOverviewEntry>> fetchFamilyOverview(String token) =>
      _request(
        '/auth/family/overview',
        token: token,
        parse: (data) =>
            _asList(data).map(FamilyOverviewEntry.fromJson).toList(),
      );

  Future<void> deleteFamilyAccount(String token) =>
      _request('/auth/family', method: 'DELETE', token: token, parse: (_) {});

  Future<FamilyStreakSettings> fetchFamilyStreakSettings(String token) =>
      _request(
        '/auth/family/streaks',
        token: token,
        parse: (data) => FamilyStreakSettings.fromJson(_asMap(data)),
      );

  Future<void> updateFamilyStreakSettings(
    String token,
    FamilyStreakSettings settings,
  ) => _request(
    '/auth/family/streaks',
    method: 'PATCH',
    token: token,
    body: settings.toJson(),
    parse: (_) {},
  );

  // ---- Privileges ----

  Future<List<PrivilegeDefinition>> fetchPrivileges(String token) => _request(
    '/privileges',
    token: token,
    parse: (data) => _asList(data).map(PrivilegeDefinition.fromJson).toList(),
  );

  Future<PrivilegeDefinition> createPrivilege(
    String token, {
    required String title,
    required num cost,
    String? description,
  }) => _request(
    '/privileges',
    method: 'POST',
    token: token,
    body: {'title': title, 'cost': cost, 'description': ?description},
    parse: (data) => PrivilegeDefinition.fromJson(_asMap(data)),
  );

  Future<PrivilegeDefinition> updatePrivilege(
    String token,
    String privilegeId, {
    String? title,
    String? description,
    num? cost,
  }) => _request(
    '/privileges/$privilegeId',
    method: 'PATCH',
    token: token,
    body: {'title': ?title, 'description': ?description, 'cost': ?cost},
    parse: (data) => PrivilegeDefinition.fromJson(_asMap(data)),
  );

  Future<void> deletePrivilege(String token, String privilegeId) => _request(
    '/privileges/$privilegeId',
    method: 'DELETE',
    token: token,
    parse: (_) {},
  );

  Future<PrivilegeRequestEntry> requestPrivilege(
    String token,
    String privilegeId,
  ) => _request(
    '/privileges/$privilegeId/request',
    method: 'POST',
    token: token,
    parse: (data) => PrivilegeRequestEntry.fromJson(_asMap(data)),
  );

  Future<PrivilegeRequestEntry> requestCustomPrivilege(
    String token, {
    required String title,
    required num cost,
    String? note,
  }) => _request(
    '/privileges/custom-request',
    method: 'POST',
    token: token,
    body: {'title': title, 'cost': cost, 'note': ?note},
    parse: (data) => PrivilegeRequestEntry.fromJson(_asMap(data)),
  );

  Future<List<PrivilegeRequestEntry>> fetchPrivilegeRequests(String token) =>
      _request(
        '/privileges/requests',
        token: token,
        parse: (data) =>
            _asList(data).map(PrivilegeRequestEntry.fromJson).toList(),
      );

  Future<List<PrivilegeRequestEntry>> fetchMyPrivilegeRequests(String token) =>
      _request(
        '/privileges/my-requests',
        token: token,
        parse: (data) =>
            _asList(data).map(PrivilegeRequestEntry.fromJson).toList(),
      );

  Future<PrivilegeRequestEntry> decidePrivilegeRequest(
    String token,
    String requestId, {
    required bool approve,
    String? note,
  }) => _request(
    '/privileges/requests/$requestId/decision',
    method: 'POST',
    token: token,
    body: {'status': approve ? 'APPROVED' : 'REJECTED', 'note': ?note},
    parse: (data) => PrivilegeRequestEntry.fromJson(_asMap(data)),
  );

  Future<PrivilegeRequestEntry> terminatePrivilegeRequest(
    String token,
    String requestId, {
    String? note,
  }) => _request(
    '/privileges/requests/$requestId/terminate',
    method: 'POST',
    token: token,
    body: {'note': ?note},
    parse: (data) => PrivilegeRequestEntry.fromJson(_asMap(data)),
  );

  // ---- Points ----

  Future<List<PointEntry>> fetchPointEntries(
    String token, {
    String? scope,
    int? limit,
    String? childId,
  }) {
    final query = <String, String>{
      'scope': ?scope,
      if (limit != null) 'limit': '$limit',
      'childId': ?childId,
    };
    final search = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _request(
      '/points$search',
      token: token,
      parse: (data) => _asList(data).map(PointEntry.fromJson).toList(),
    );
  }

  Future<List<PointEntry>> fetchPointHistory(
    String token, {
    String? childId,
    int? limit,
  }) {
    final query = <String, String>{
      'childId': ?childId,
      if (limit != null) 'limit': '$limit',
    };
    final search = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return _request(
      '/points/history$search',
      token: token,
      parse: (data) => _asList(data).map(PointEntry.fromJson).toList(),
    );
  }

  Future<PointEntry> createPointEntry(
    String token, {
    required String childId,
    required PointEntryType type,
    required num amount,
    String? note,
  }) => _request(
    '/points',
    method: 'POST',
    token: token,
    body: {
      'childId': childId,
      'type': pointEntryTypeToJson(type),
      'amount': amount,
      'note': ?note,
    },
    parse: (data) => PointEntry.fromJson(_asMap(data)),
  );

  // ---- Nudges ----

  Future<List<NudgeSetting>> fetchNudges(String token, {String? childId}) {
    final search = childId != null ? '?childId=$childId' : '';
    return _request(
      '/nudges$search',
      token: token,
      parse: (data) => _asList(data).map(NudgeSetting.fromJson).toList(),
    );
  }

  Future<List<NudgeSetting>> updateNudges(
    String token,
    String childId,
    List<NudgeUpdateItem> nudges,
  ) => _request(
    '/nudges',
    method: 'PATCH',
    token: token,
    body: {
      'childId': childId,
      'nudges': nudges.map((n) => n.toJson()).toList(),
    },
    parse: (data) => _asList(data).map(NudgeSetting.fromJson).toList(),
  );

  // ---- Tasks ----

  Future<List<TaskSummary>> fetchTasks(String token) => _request(
    '/tasks',
    token: token,
    parse: (data) => _asList(data).map(TaskSummary.fromJson).toList(),
  );

  Future<TaskDetail> fetchTaskDetail(String token, String taskId) => _request(
    '/tasks/$taskId',
    token: token,
    parse: (data) => TaskDetail.fromJson(_asMap(data)),
  );

  Future<List<TaskHistoryEntry>> fetchTaskHistory(
    String token, {
    String? childId,
  }) {
    final query = childId != null ? '?childId=$childId' : '';
    return _request(
      '/tasks/history$query',
      token: token,
      parse: (data) => _asList(data).map(TaskHistoryEntry.fromJson).toList(),
    );
  }

  Future<String?> createTask(
    String token, {
    required String title,
    String? description,
    String? icon,
    String? reminderStyle,
    String? frequency,
    List<String>? daysOfWeek,
    num? points,
    DateTime? dueAt,
  }) => _request(
    '/tasks',
    method: 'POST',
    token: token,
    body: {
      'title': title,
      'description': ?description,
      'icon': ?icon,
      'reminderStyle': ?reminderStyle,
      'frequency': ?frequency,
      'daysOfWeek': ?daysOfWeek,
      'points': ?points,
      'dueAt': dueAt?.toIso8601String(),
    },
    parse: (data) => (data is Map) ? data['id'] as String? : null,
  );

  Future<void> assignTask(String token, String taskId, String childId) =>
      _request(
        '/tasks/$taskId/assign',
        method: 'POST',
        token: token,
        body: {'childId': childId},
        parse: (_) {},
      );

  Future<void> completeTask(
    String token,
    String taskId, {
    String? status,
    String? childId,
  }) => _request(
    '/tasks/$taskId/complete',
    method: 'POST',
    token: token,
    body: {'status': ?status, 'childId': ?childId},
    parse: (_) {},
  );

  Future<void> unassignTask(String token, String taskId, String childId) =>
      _request(
        '/tasks/$taskId/assign/$childId',
        method: 'DELETE',
        token: token,
        parse: (_) {},
      );

  Future<void> deleteTask(String token, String taskId) =>
      _request('/tasks/$taskId', method: 'DELETE', token: token, parse: (_) {});

  // ---- Routine templates ----

  Future<List<RoutineTemplate>> fetchRoutineTemplates(String token) => _request(
    '/routines/templates',
    token: token,
    parse: (data) => _asList(data).map(RoutineTemplate.fromJson).toList(),
  );

  Future<RoutineTemplate> fetchRoutineTemplateDetail(
    String token,
    String templateId,
  ) => _request(
    '/routines/templates/$templateId',
    token: token,
    parse: (data) => RoutineTemplate.fromJson(_asMap(data)),
  );

  Future<String?> createRoutineTemplate(
    String token, {
    required String name,
    required List<Map<String, dynamic>> items,
    String? description,
    String? frequency,
    List<String>? daysOfWeek,
    String? rewardNote,
  }) => _request(
    '/routines/templates',
    method: 'POST',
    token: token,
    body: {
      'name': name,
      'items': items,
      'description': ?description,
      'frequency': ?frequency,
      'daysOfWeek': ?daysOfWeek,
      'rewardNote': ?rewardNote,
    },
    parse: (data) => data is Map ? data['id'] as String? : null,
  );

  Future<void> assignRoutineTemplate(
    String token,
    String templateId,
    String childId,
  ) => _request(
    '/routines/templates/$templateId/assign',
    method: 'POST',
    token: token,
    body: {'childId': childId},
    parse: (_) {},
  );

  Future<void> updateRoutineTemplate(
    String token,
    String templateId, {
    required List<Map<String, dynamic>> items,
    String? name,
    String? description,
    String? rewardNote,
    String? frequency,
    List<String>? daysOfWeek,
  }) => _request(
    '/routines/templates/$templateId',
    method: 'PATCH',
    token: token,
    body: {
      'items': items,
      'name': ?name,
      'description': ?description,
      'rewardNote': ?rewardNote,
      'frequency': ?frequency,
      'daysOfWeek': ?daysOfWeek,
    },
    parse: (_) {},
  );

  Future<void> deleteRoutineTemplate(String token, String templateId) =>
      _request(
        '/routines/templates/$templateId',
        method: 'DELETE',
        token: token,
        parse: (_) {},
      );

  Future<void> unassignRoutineTemplate(
    String token,
    String templateId,
    String childId,
  ) => _request(
    '/routines/templates/$templateId/assign/$childId',
    method: 'DELETE',
    token: token,
    parse: (_) {},
  );
}
