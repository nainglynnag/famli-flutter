import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase_api_client.dart';
import '../models/family.dart';
import '../models/nudge.dart';
import '../models/point.dart';
import '../models/privilege.dart';
import '../models/routine.dart';
import '../models/task.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Screen-level data providers, mirroring the useQuery() calls scattered
/// through mobile/app/(app)/*.tsx. Each one reads the current auth token and
/// throws (surfacing as AsyncError) if there isn't one — the router only
/// allows these screens to be reached while authenticated.
String _requireToken(Ref ref) {
  final token = ref.watch(authProvider).value?.token;
  if (token == null) {
    throw StateError('No auth token — screen reached while signed out.');
  }
  return token;
}

final tasksProvider = StreamProvider.autoDispose<List<TaskSummary>>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api is FirebaseApiClient) {
    return api.watchTasks();
  }
  return Stream.fromFuture(api.fetchTasks(_requireToken(ref)));
});

final familyStreakSettingsProvider =
    FutureProvider.autoDispose<FamilyStreakSettings>((ref) {
      final api = ref.watch(apiClientProvider);
      return api.fetchFamilyStreakSettings(_requireToken(ref));
    });

final todayPointEntriesProvider = FutureProvider.autoDispose<List<PointEntry>>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return api.fetchPointEntries(_requireToken(ref), scope: 'today', limit: 5);
});

/// Used by the Points screen itself (mobile/app/(app)/points/index.tsx),
/// which asks for a larger page than the home dashboard's summary widget.
final pointsScreenEntriesProvider =
    FutureProvider.autoDispose<List<PointEntry>>((ref) {
      final api = ref.watch(apiClientProvider);
      return api.fetchPointEntries(
        _requireToken(ref),
        scope: 'today',
        limit: 25,
      );
    });

final pointHistoryProvider = FutureProvider.autoDispose<List<PointEntry>>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return api.fetchPointHistory(_requireToken(ref));
});

final privilegeRequestsProvider =
    StreamProvider.autoDispose<List<PrivilegeRequestEntry>>((ref) {
      final api = ref.watch(apiClientProvider);
      if (api is FirebaseApiClient) {
        return api.watchPrivilegeRequests();
      }
      return Stream.fromFuture(
        api.fetchPrivilegeRequests(_requireToken(ref)),
      );
    });

final myPrivilegeRequestsProvider =
    StreamProvider.autoDispose<List<PrivilegeRequestEntry>>((ref) {
      final api = ref.watch(apiClientProvider);
      if (api is FirebaseApiClient) {
        return api.watchMyPrivilegeRequests();
      }
      return Stream.fromFuture(
        api.fetchMyPrivilegeRequests(_requireToken(ref)),
      );
    });

final childSeedBalanceProvider = StreamProvider.autoDispose<int>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api is FirebaseApiClient) {
    return api.watchChildSeedBalance();
  }
  final profile = ref.watch(authProvider).value?.profile;
  return Stream.value(profile?.progress?.seedBalance ?? 0);
});

final privilegesProvider =
    FutureProvider.autoDispose<List<PrivilegeDefinition>>((ref) {
      final api = ref.watch(apiClientProvider);
      return api.fetchPrivileges(_requireToken(ref));
    });

final familyMembersProvider = FutureProvider.autoDispose<List<FamilyMember>>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return api.fetchFamilyMembers(_requireToken(ref));
});

final familyOverviewProvider =
    StreamProvider.autoDispose<List<FamilyOverviewEntry>>((ref) {
      final api = ref.watch(apiClientProvider);
      if (api is FirebaseApiClient) {
        return api.watchFamilyOverview();
      }
      return Stream.fromFuture(api.fetchFamilyOverview(_requireToken(ref)));
    });

final taskHistoryProvider = FutureProvider.autoDispose<List<TaskHistoryEntry>>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return api.fetchTaskHistory(_requireToken(ref));
});

final routineTemplatesProvider =
    StreamProvider.autoDispose<List<RoutineTemplate>>((ref) {
      final api = ref.watch(apiClientProvider);
      if (api is FirebaseApiClient) {
        return api.watchRoutineTemplates();
      }
      return Stream.fromFuture(
        api.fetchRoutineTemplates(_requireToken(ref)),
      );
    });

final nudgesAdminProvider = FutureProvider.autoDispose<List<NudgeSetting>>((
  ref,
) {
  final api = ref.watch(apiClientProvider);
  return api.fetchNudges(_requireToken(ref));
});

final childNudgesProvider = FutureProvider.autoDispose
    .family<List<NudgeSetting>, String>((ref, childId) {
      final api = ref.watch(apiClientProvider);
      return api.fetchNudges(_requireToken(ref), childId: childId);
    });

final taskDetailProvider = FutureProvider.autoDispose
    .family<TaskDetail, String>((ref, taskId) {
      final api = ref.watch(apiClientProvider);
      return api.fetchTaskDetail(_requireToken(ref), taskId);
    });

final routineTemplateDetailProvider = FutureProvider.autoDispose
    .family<RoutineTemplate, String>((ref, templateId) {
      final api = ref.watch(apiClientProvider);
      return api.fetchRoutineTemplateDetail(_requireToken(ref), templateId);
    });
