import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/nudge_templates.dart';
import '../constants/starter_templates.dart';
import '../models/family.dart';
import '../models/nudge.dart';
import '../models/point.dart';
import '../models/privilege.dart';
import '../models/routine.dart';
import '../models/task.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'family_time.dart';
import 'firebase_bootstrap.dart';
import 'seed_progress.dart';

/// Firestore-backed implementation of the same surface as [ApiClient].
///
/// Declaring `implements ApiClient` reuses the REST client's implicit interface,
/// so screens and Riverpod providers are unchanged — swapping backends is a
/// one-line change in providers/api_provider.dart, and the REST client stays
/// usable while the migration is in progress.
///
/// The `token` parameter every method takes is vestigial here: Firebase Auth
/// manages the session itself. It is kept so the signatures still match.
///
/// See daily-buddies/FIREBASE_MIGRATION_PLAN.md for the collection layout.
class FirebaseApiClient implements ApiClient {
  FirebaseApiClient({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  late final SeedProgress _progress = SeedProgress(_db);

  /// Firebase Auth has no username sign-in, so accounts created without a real
  /// email get a synthetic one. Must match FIREBASE_MIGRATION_PLAN.md §4.
  static const String _usernameEmailDomain = 'users.dailybuddies.app';

  String _syntheticEmail(String username) => '$username@$_usernameEmailDomain';

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  DocumentReference<Map<String, dynamic>> _family(String familyId) =>
      _db.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> _tasks(String familyId) =>
      _family(familyId).collection('tasks');

  CollectionReference<Map<String, dynamic>> _taskAssignments(String familyId) =>
      _family(familyId).collection('taskAssignments');

  CollectionReference<Map<String, dynamic>> _routineTemplates(
    String familyId,
  ) => _family(familyId).collection('routineTemplates');

  CollectionReference<Map<String, dynamic>> _routineAssignments(
    String familyId,
  ) => _family(familyId).collection('routineAssignments');

  CollectionReference<Map<String, dynamic>> _pointAdjustments(
    String familyId,
  ) => _family(familyId).collection('pointAdjustments');

  CollectionReference<Map<String, dynamic>> _streakRewardLogs(
    String familyId,
  ) => _family(familyId).collection('streakRewardLogs');

  CollectionReference<Map<String, dynamic>> _taskCompletions(
    String familyId,
  ) => _family(familyId).collection('taskCompletions');

  Future<void> _notifyCompletionChange(
    String familyId, [
    String? taskId,
    String? childId,
  ]) async {
    try {
      await _taskCompletions(familyId).doc('sync').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'taskId': ?taskId,
        'childId': ?childId,
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort completion ping
    }
  }

  /// Assignments use a deterministic id so assign/unassign is idempotent,
  /// replacing the @@unique([taskId, childId]) constraint Prisma enforced.
  String _assignmentId(String taskId, String childId) => '${taskId}_$childId';

  User get _currentUser {
    final user = _auth.currentUser;
    if (user == null) {
      throw ApiException('Not signed in');
    }
    return user;
  }

  /// Translates Firebase's error codes into the same user-facing messages the
  /// Express API returned, so existing screens keep showing sensible text.
  Never _rethrowAsApiException(Object error) {
    if (error is ApiException) throw error;
    if (error is FirebaseAuthException) {
      throw ApiException(switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Invalid credentials',
        'email-already-in-use' => 'Email already registered',
        'weak-password' => 'Password is too weak',
        'invalid-email' => 'Invalid email address',
        'network-request-failed' => 'Network error',
        _ => error.message ?? 'Something went wrong',
      });
    }
    if (error is FirebaseException) {
      throw ApiException(
        error.code == 'permission-denied'
            ? 'Action not permitted'
            : error.message ?? 'Something went wrong',
      );
    }
    throw ApiException('Something went wrong');
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error) {
      _rethrowAsApiException(error);
    }
  }

  String _sanitize(String value) => value.trim().toLowerCase();

  /// Resolves a login identifier to an email address. Usernames are looked up
  /// in the public `usernames` collection, which is readable signed-out
  /// precisely so this can run before sign-in.
  Future<String> _resolveEmail(String identifier) async {
    final value = _sanitize(identifier);
    if (value.contains('@')) return value;

    final doc = await _usernames.doc(value).get();
    final email = doc.data()?['email'] as String?;
    if (email == null) {
      throw ApiException('Invalid credentials');
    }
    return email;
  }

  Future<UserSummary> _loadProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      throw ApiException('User not found');
    }

    final familyId = data['familyId'] as String?;
    Map<String, dynamic>? family;
    if (familyId != null) {
      final familySnapshot = await _family(familyId).get();
      final familyData = familySnapshot.data();
      if (familyData != null) {
        family = {
          'id': familyId,
          'name': familyData['name'],
          'timezone': familyData['timezone'],
        };
      }
    }

    // Derived, never stored — see SeedProgress. Only children have a balance
    // or streak, matching the shape the Express API returned.
    Map<String, dynamic>? progress;
    if (data['role'] == 'CHILD' && familyId != null) {
      final snapshot = await _progress.childProgressSnapshot(
        familyId,
        uid,
        family?['timezone'] as String? ?? 'UTC',
      );
      progress = {
        'seedBalance': snapshot.seedBalance,
        'streak': snapshot.streak,
      };
    }

    return UserSummary.fromJson({
      'id': uid,
      'name': data['name'],
      'username': data['username'],
      'role': data['role'],
      'email': data['email'],
      'avatarTone': data['avatarTone'],
      'photoUrl': data['photoUrl'],
      'familyId': familyId,
      'family': family,
      'progress': progress,
    });
  }

  // ---- Auth ----

  @override
  Future<LoginResponse> login(String identifier, String password) =>
      _guard(() async {
        final email = await _resolveEmail(identifier);
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = credential.user!.uid;
        return LoginResponse(
          token: await credential.user!.getIdToken() ?? '',
          user: await _loadProfile(uid),
        );
      });

  @override
  Future<RegisterParentResponse> registerParent(
    RegisterParentPayload payload,
  ) => _guard(() async {
    final username = _sanitize(payload.parent.username);
    final email = _sanitize(payload.parent.email);

    if ((await _usernames.doc(username).get()).exists) {
      throw ApiException('Username already taken');
    }

    // Self-registration, so signing in as the new user is the desired outcome
    // (unlike createChild/inviteParent, which must not touch this session).
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: payload.parent.password,
    );
    final uid = credential.user!.uid;

    try {
      final familyRef = _db.collection('families').doc();
      final batch = _db.batch();

      batch.set(familyRef, {
        'name': payload.familyName,
        'timezone': 'UTC',
        'dailyStreakReward': 0,
        'weeklyStreakReward': 0,
        'monthlyStreakReward': 0,
        'yearlyStreakReward': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(_users.doc(uid), {
        'name': payload.parent.name,
        'email': email,
        'username': username,
        'role': 'PARENT',
        'avatarTone': null,
        'familyId': familyRef.id,
        'parentId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // A create on an existing document fails, which makes username
      // uniqueness race-proof without any server-side check.
      batch.set(_usernames.doc(username), {'uid': uid, 'email': email});

      for (final template in starterTemplates) {
        final templateRef = familyRef.collection('routineTemplates').doc();
        batch.set(templateRef, {
          'name': template['name'],
          'description': template['description'],
          'frequency': template['frequency'],
          'rewardNote': template['rewardNote'],
          'daysOfWeek': template['daysOfWeek'],
          'createdById': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        for (final item in template['items'] as List) {
          final data = item as Map<String, dynamic>;
          batch.set(templateRef.collection('items').doc(), {
            'title': data['title'],
            'icon': data['icon'],
            'points': data['points'],
            'reminderStyle': 'FRIENDLY',
          });
        }
      }

      await batch.commit();

      return RegisterParentResponse(
        token: await credential.user!.getIdToken() ?? '',
        parent: await _loadProfile(uid),
      );
    } catch (error) {
      // Without a server there is no transaction spanning Auth and Firestore,
      // so an account whose documents failed to write must be removed here or
      // it would be able to sign in with no family. See §7 of the plan: a
      // client that dies before this runs still leaves one behind.
      await credential.user?.delete();
      rethrow;
    }
  });

  @override
  Future<UserSummary> fetchProfile(String token) =>
      _guard(() => _loadProfile(_currentUser.uid));

  @override
  Future<UserSummary> updateProfile(
    String token, {
    String? name,
    String? avatarTone,
    String? photoUrl,
    String? currentPassword,
    String? newPassword,
    String? familyTimezone,
  }) => _guard(() async {
    final user = _currentUser;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (avatarTone != null) updates['avatarTone'] = avatarTone;
    if (photoUrl != null) updates['photoUrl'] = photoUrl.isEmpty ? null : photoUrl;

    if (newPassword != null) {
      if (currentPassword == null) {
        throw ApiException('Current password required to change password');
      }
      // Firebase requires a recent sign-in before a password change; the old
      // API verified the current password itself.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    }

    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _users.doc(user.uid).update(updates);
    }

    if (familyTimezone != null) {
      final profile = await _users.doc(user.uid).get();
      final familyId = profile.data()?['familyId'] as String?;
      if (familyId == null) {
        throw ApiException('Family not linked yet');
      }
      // Rules reject this for a CHILD, matching requireRole(PARENT).
      await _family(familyId).update({
        'timezone': familyTimezone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    return _loadProfile(user.uid);
  });

  // ---- Family ----

  Future<String> _myFamilyId() async {
    final snapshot = await _users.doc(_currentUser.uid).get();
    final familyId = snapshot.data()?['familyId'] as String?;
    if (familyId == null) {
      throw ApiException('Family not linked yet');
    }
    return familyId;
  }

  Future<String> _myRole() async {
    final snapshot = await _users.doc(_currentUser.uid).get();
    return snapshot.data()?['role'] as String? ?? 'CHILD';
  }

  /// Replaces req.user.familyTimezone: the family document is the single
  /// source of truth for which day "today" is.
  Future<String> _familyTimeZone(String familyId) async {
    final snapshot = await _family(familyId).get();
    return snapshot.data()?['timezone'] as String? ?? 'UTC';
  }

  @override
  Future<List<FamilyMember>> fetchFamilyMembers(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final snapshot = await _users
            .where('familyId', isEqualTo: familyId)
            .get();

        final docs = snapshot.docs.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null || bCreated == null) return 0;
            return aCreated.compareTo(bCreated);
          });

        return docs
            .map((doc) => FamilyMember.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
      });

  Future<FamilyMember> _createMember({
    required String name,
    required String username,
    required String password,
    required String role,
    String? email,
    String? avatarTone,
  }) async {
    final normalizedUsername = _sanitize(username);
    final normalizedEmail = email == null ? null : _sanitize(email);
    final familyId = await _myFamilyId();
    final parentUid = _currentUser.uid;

    if ((await _usernames.doc(normalizedUsername).get()).exists) {
      throw ApiException('Username already taken');
    }

    final loginEmail = normalizedEmail ?? _syntheticEmail(normalizedUsername);

    // Runs on a secondary FirebaseApp so the signed-in parent keeps their
    // session — see createAccountWithoutSignIn.
    final uid = await createAccountWithoutSignIn(
      email: loginEmail,
      password: password,
    );

    try {
      final batch = _db.batch();
      batch.set(_users.doc(uid), {
        'name': name,
        'email': normalizedEmail,
        'username': normalizedUsername,
        'role': role,
        'avatarTone': avatarTone,
        'familyId': familyId,
        'parentId': role == 'CHILD' ? parentUid : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_usernames.doc(normalizedUsername), {
        'uid': uid,
        'email': loginEmail,
      });
      await batch.commit();
    } catch (e) {
      // Roll back the created Auth account if Firestore write fails
      try {
        final app = await secondaryApp();
        final secondaryAuth = FirebaseAuth.instanceFor(app: app);
        final cred = await secondaryAuth.signInWithEmailAndPassword(
          email: loginEmail,
          password: password,
        );
        await cred.user?.delete();
      } catch (_) {
        // Best-effort cleanup
      }
      rethrow;
    }

    return FamilyMember(
      id: uid,
      name: name,
      username: normalizedUsername,
      role: userRoleFromJson(role),
      email: normalizedEmail,
      avatarTone: avatarTone,
    );
  }

  @override
  Future<FamilyMember> createChild(
    String token, {
    required String name,
    required String username,
    required String password,
    String? email,
    String? avatarTone,
  }) => _guard(
    () => _createMember(
      name: name,
      username: username,
      password: password,
      role: 'CHILD',
      email: email,
      avatarTone: avatarTone,
    ),
  );

  @override
  Future<FamilyMember> inviteParent(
    String token, {
    required String name,
    required String username,
    required String email,
    required String password,
  }) => _guard(
    () => _createMember(
      name: name,
      username: username,
      password: password,
      role: 'PARENT',
      email: email,
    ),
  );

  @override
  Future<FamilyMember> updateFamilyMember(
    String token,
    String userId, {
    String? name,
    String? username,
    String? avatarTone,
    String? newPassword,
  }) => _guard(() async {
    if (newPassword != null) {
      // Changing another user's password needs the Admin SDK, which needs
      // Cloud Functions (Blaze). See FIREBASE_MIGRATION_PLAN.md §7.
      throw ApiException(
        'Changing another member\'s password requires a server; '
        'ask them to sign in and change it themselves.',
      );
    }

    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) updates['name'] = name;
    if (avatarTone != null) updates['avatarTone'] = avatarTone;

    if (username != null) {
      final normalized = _sanitize(username);
      final existing = await _users.doc(userId).get();
      final currentUsername = existing.data()?['username'] as String?;

      if (normalized != currentUsername) {
        if ((await _usernames.doc(normalized).get()).exists) {
          throw ApiException('Username already taken');
        }
        final email =
            existing.data()?['email'] as String? ?? _syntheticEmail(normalized);
        final batch = _db.batch();
        batch.set(_usernames.doc(normalized), {'uid': userId, 'email': email});
        if (currentUsername != null) {
          batch.delete(_usernames.doc(currentUsername));
        }
        await batch.commit();
        updates['username'] = normalized;
      }
    }

    await _users.doc(userId).update(updates);
    final snapshot = await _users.doc(userId).get();
    return FamilyMember.fromJson({...snapshot.data()!, 'id': userId});
  });

  @override
  Future<void> deleteFamilyMember(String token, String userId) =>
      _guard(() async {
        final snapshot = await _users.doc(userId).get();
        final username = snapshot.data()?['username'] as String?;

        final batch = _db.batch();
        batch.delete(_users.doc(userId));
        if (username != null) batch.delete(_usernames.doc(username));
        await batch.commit();

        // Their Auth account survives — deleting it needs the Admin SDK. With
        // the users/ document gone every rule fails closed, so they can sign
        // in but read nothing. See FIREBASE_MIGRATION_PLAN.md §7.
      });

  @override
  Future<FamilyStreakSettings> fetchFamilyStreakSettings(String token) =>
      _guard(() async {
        final snapshot = await _family(await _myFamilyId()).get();
        return FamilyStreakSettings.fromJson(snapshot.data()!);
      });

  @override
  Future<void> updateFamilyStreakSettings(
    String token,
    FamilyStreakSettings settings,
  ) => _guard(() async {
    await _family(await _myFamilyId()).update({
      ...settings.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  // ---- Tasks ----

  int _byCreatedAtDesc(
    DocumentSnapshot<Map<String, dynamic>> a,
    DocumentSnapshot<Map<String, dynamic>> b,
  ) {
    final at = (a.data()?['createdAt'] as Timestamp?)?.millisecondsSinceEpoch;
    final bt = (b.data()?['createdAt'] as Timestamp?)?.millisecondsSinceEpoch;
    return (bt ?? 0).compareTo(at ?? 0);
  }

  Future<String?> _routineName(String familyId, String? templateId) async {
    if (templateId == null) return null;
    final snapshot = await _routineTemplates(familyId).doc(templateId).get();
    return snapshot.data()?['name'] as String?;
  }

  Future<List<TaskAssignment>> _assignmentsForTask(
    String familyId,
    String taskId,
    Map<String, dynamic> taskData,
    DateTime today,
    String todayKey,
  ) async {
    final assignments = await _taskAssignments(
      familyId,
    ).where('taskId', isEqualTo: taskId).get();

    final result = <TaskAssignment>[];
    for (final assignment in assignments.docs) {
      final childId = assignment.data()['childId'] as String;
      final child = (await _users.doc(childId).get()).data();
      if (child == null) continue;

      final eval = await _progress.evaluateTaskForChild(
        familyId: familyId,
        taskId: taskId,
        taskData: taskData,
        childId: childId,
        today: today,
        todayKey: todayKey,
      );

      result.add(
        TaskAssignment(
          childId: childId,
          childName: child['name'] as String,
          childAvatarTone: child['avatarTone'] as String?,
          childPhotoUrl: child['photoUrl'] as String?,
          status: eval.status,
          isApplicableToday: eval.isApplicable,
        ),
      );
    }
    return result;
  }

  @override
  Future<List<TaskSummary>> fetchTasks(String token) => _guard(() async {
    final familyId = await _myFamilyId();
    final timeZone = await _familyTimeZone(familyId);
    final today = startOfDayInTimeZone(timeZone);
    final todayKey = weekdayKeyForTimeZone(timeZone);

    if (await _myRole() == 'CHILD') {
      final uid = _currentUser.uid;
      final assignments = await _taskAssignments(
        familyId,
      ).where('childId', isEqualTo: uid).get();

      final tasks = await Future.wait(
        assignments.docs.map(
          (doc) => _tasks(familyId).doc(doc.data()['taskId'] as String).get(),
        ),
      );

      final summaries = <TaskSummary>[];
      for (final snapshot in tasks) {
        final data = snapshot.data();
        if (data == null || data['active'] != true) continue;

        final eval = await _progress.evaluateTaskForChild(
          familyId: familyId,
          taskId: snapshot.id,
          taskData: data,
          childId: uid,
          today: today,
          todayKey: todayKey,
        );
        if (!eval.isApplicable) continue;

        final routineId = data['routineTemplateId'] as String?;
        final rName = routineId != null
            ? (await _routineName(familyId, routineId) ??
                data['routineName'] as String? ??
                'Routine')
            : null;
        summaries.add(
          TaskSummary(
            id: snapshot.id,
            title: data['title'] as String,
            points: data['points'] as num,
            icon: data['icon'] as String?,
            reminderStyle: data['reminderStyle'] as String?,
            frequency: data['frequency'] as String?,
            status: eval.status,
            routineName: rName,
            routineId: routineId,
            daysOfWeek: (data['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
            dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
          ),
        );
      }
      return summaries;
    }

    final tasks = await _tasks(familyId).get();
    final summaries = <TaskSummary>[];
    for (final task in tasks.docs) {
      final data = task.data();
      if (data['active'] != true) continue;

      final assignments = await _assignmentsForTask(
        familyId,
        task.id,
        data,
        today,
        todayKey,
      );

      // If standalone task was completed before today for all assigned children,
      // it is completed and should not appear in today's active summaries.
      if (assignments.isNotEmpty &&
          assignments.every((a) => !a.isApplicableToday)) {
        continue;
      }

      // If it's a routine task and it's not active today, skip from today's summaries
      if (data['routineTemplateId'] != null &&
          !isActiveOnDay(data['daysOfWeek'] as List<dynamic>?, todayKey)) {
        continue;
      }

      summaries.add(
        TaskSummary(
          id: task.id,
          title: data['title'] as String,
          points: data['points'] as num,
          routineName: await _routineName(
            familyId,
            data['routineTemplateId'] as String?,
          ),
          daysOfWeek: (data['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
          assignments: assignments,
          dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
        ),
      );
    }
    return summaries;
  });

  /// Real-time stream of tasks that auto-updates when Firestore changes.
  Stream<List<TaskSummary>> watchTasks() {
    late final StreamController<List<TaskSummary>> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    Future<void> emitTasks() async {
      try {
        final tasks = await fetchTasks('');
        if (!controller.isClosed) {
          controller.add(tasks);
        }
      } catch (_) {
        // preserve previous state on transient network errors
      }
    }

    controller = StreamController<List<TaskSummary>>(
      onListen: () async {
        try {
          final familyId = await _myFamilyId();
          await emitTasks();

          subscriptions.add(
            _tasks(familyId).snapshots().listen((_) => emitTasks()),
          );
          subscriptions.add(
            _taskAssignments(familyId).snapshots().listen((_) => emitTasks()),
          );
          subscriptions.add(
            _taskCompletions(familyId).snapshots().listen((_) => emitTasks()),
          );
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  @override
  Future<TaskDetail> fetchTaskDetail(String token, String taskId) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final data = (await _tasks(familyId).doc(taskId).get()).data();
        if (data == null) throw ApiException('Task not found');

        if (await _myRole() == 'CHILD') {
          final assignment = await _taskAssignments(
            familyId,
          ).doc(_assignmentId(taskId, _currentUser.uid)).get();
          if (!assignment.exists) {
            throw ApiException('You are not assigned to this task');
          }
        }

        final timeZone = await _familyTimeZone(familyId);
        final today = startOfDayInTimeZone(timeZone);

        final completionDocs = await _tasks(familyId)
            .doc(taskId)
            .collection('completions')
            .orderBy('date', descending: true)
            .limit(20)
            .get();

        final completions = <TaskCompletion>[];
        for (final doc in completionDocs.docs) {
          final completion = doc.data();
          final childId = completion['childId'] as String;
          final child = (await _users.doc(childId).get()).data();
          completions.add(
            TaskCompletion(
              id: doc.id,
              childId: childId,
              childName: child?['name'] as String? ?? 'Unknown',
              childAvatarTone: child?['avatarTone'] as String?,
              childPhotoUrl: child?['photoUrl'] as String?,
              status: completion['status'] as String,
              date:
                  (completion['date'] as Timestamp?)
                      ?.toDate()
                      .toIso8601String() ??
                  '',
            ),
          );
        }

        return TaskDetail(
          id: taskId,
          title: data['title'] as String,
          description: data['description'] as String?,
          icon: data['icon'] as String?,
          points: data['points'] as num,
          reminderStyle: data['reminderStyle'] as String? ?? 'FRIENDLY',
          frequency: data['frequency'] as String? ?? 'DAILY',
          daysOfWeek: (data['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
          routineName: await _routineName(
            familyId,
            data['routineTemplateId'] as String?,
          ),
          assignments: await _assignmentsForTask(
            familyId,
            taskId,
            data,
            today,
            weekdayKeyForTimeZone(timeZone),
          ),
          completions: completions,
          dueAt: (data['dueAt'] as Timestamp?)?.toDate(),
        );
      });

  @override
  Future<List<TaskHistoryEntry>> fetchTaskHistory(
    String token, {
    String? childId,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final role = await _myRole();
    final targetChildId = role == 'CHILD' ? _currentUser.uid : childId;
    final tasks = await _tasks(familyId).get();

    final rows = <Map<String, dynamic>>[];
    for (final task in tasks.docs) {
      final completions = task.reference.collection('completions');
      // An equality filter plus an orderBy on another field would need a
      // composite index, so the filtered case sorts client-side instead.
      final snapshot = targetChildId != null
          ? await completions.where('childId', isEqualTo: targetChildId).get()
          : await completions.orderBy('date', descending: true).limit(50).get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        rows.add({
          'id': doc.id,
          'taskTitle': task.data()['title'],
          'childId': data['childId'],
          'points': data['seedsEarned'],
          'status': data['status'],
          'date': (data['date'] as Timestamp?)?.toDate(),
        });
      }
    }

    rows.sort((a, b) {
      final at = (a['date'] as DateTime?)?.millisecondsSinceEpoch ?? 0;
      final bt = (b['date'] as DateTime?)?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });

    final entries = <TaskHistoryEntry>[];
    for (final row in rows.take(50)) {
      final child = role == 'CHILD'
          ? null
          : (await _users.doc(row['childId'] as String).get()).data();
      entries.add(
        TaskHistoryEntry(
          id: row['id'] as String,
          taskTitle: row['taskTitle'] as String,
          childName: child?['name'] as String?,
          points: row['points'] as num?,
          childAvatarTone: child?['avatarTone'] as String?,
          status: row['status'] as String,
          date: (row['date'] as DateTime?)?.toIso8601String() ?? '',
        ),
      );
    }
    return entries;
  });

  @override
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
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final ref = _tasks(familyId).doc();
    await ref.set({
      'title': title,
      'description': description,
      'icon': icon,
      'reminderStyle': reminderStyle ?? 'FRIENDLY',
      'frequency': frequency ?? 'DAILY',
      'daysOfWeek': daysOfWeek,
      'points': points ?? 1,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt) : null,
      'active': true,
      'createdById': _currentUser.uid,
      'routineTemplateId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  });

  @override
  Future<void> assignTask(String token, String taskId, String childId) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        await _taskAssignments(familyId).doc(_assignmentId(taskId, childId)).set(
          {
            'taskId': taskId,
            'childId': childId,
            'assignedAt': FieldValue.serverTimestamp(),
          },
        );
      });

  @override
  Future<void> completeTask(
    String token,
    String taskId, {
    String? status,
    String? childId,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final role = await _myRole();

    final String targetChildId;
    if (role == 'CHILD') {
      targetChildId = _currentUser.uid;
    } else {
      if (childId == null) throw ApiException('childId is required');
      targetChildId = childId;
    }

    final assignment = await _taskAssignments(
      familyId,
    ).doc(_assignmentId(taskId, targetChildId)).get();
    if (!assignment.exists) {
      throw ApiException(
        role == 'CHILD'
            ? 'You are not assigned to this task'
            : 'Child not assigned to this task',
      );
    }

    final task = (await _tasks(familyId).doc(taskId).get()).data();
    if (task == null) throw ApiException('Task not found');

    final timeZone = await _familyTimeZone(familyId);

    final normalizedStatus = status ?? 'COMPLETED';

    // The rules pin seedsEarned to the task's own points value whatever the
    // status, so a client cannot inflate it. Only COMPLETED entries are
    // counted toward the balance — see SeedProgress.calculateSeedBalance.
    await _tasks(familyId).doc(taskId).collection('completions').add({
      'taskId': taskId,
      'childId': targetChildId,
      'status': normalizedStatus,
      'seedsEarned': task['points'],
      'date': Timestamp.fromDate(startOfDayInTimeZone(timeZone)),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (normalizedStatus == 'COMPLETED') {
      await _progress.maybeAwardStreakRewards(
        familyId,
        targetChildId,
        timeZone,
      );
    } else {
      await _progress.maybeRevokeDailyReward(familyId, targetChildId, timeZone);
    }

    await _notifyCompletionChange(familyId, taskId, targetChildId);
  });

  @override
  Future<void> unassignTask(String token, String taskId, String childId) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final completions = await _tasks(familyId)
            .doc(taskId)
            .collection('completions')
            .where('childId', isEqualTo: childId)
            .get();

        final batch = _db.batch();
        for (final doc in completions.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(
          _taskAssignments(familyId).doc(_assignmentId(taskId, childId)),
        );
        await batch.commit();
        await _notifyCompletionChange(familyId, taskId, childId);
      });

  @override
  Future<void> deleteTask(String token, String taskId) => _guard(() async {
    final familyId = await _myFamilyId();
    final taskRef = _tasks(familyId).doc(taskId);
    final completions = await taskRef.collection('completions').get();
    final assignments = await _taskAssignments(
      familyId,
    ).where('taskId', isEqualTo: taskId).get();

    final batch = _db.batch();
    for (final doc in completions.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in assignments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(taskRef);
    await batch.commit();
    await _notifyCompletionChange(familyId, taskId);
  });

  // ---- Routine templates ----

  Future<RoutineTemplate> _loadRoutineTemplate(
    String familyId,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data();
    if (data == null) throw ApiException('Template not found');

    final items = await snapshot.reference
        .collection('items')
        .orderBy('title')
        .get();
    final assignmentDocs = await _routineAssignments(
      familyId,
    ).where('templateId', isEqualTo: snapshot.id).get();

    final assignments = <RoutineTemplateAssignment>[];
    for (final doc in assignmentDocs.docs) {
      final childId = doc.data()['childId'] as String;
      final child = (await _users.doc(childId).get()).data();
      if (child == null) continue;
      assignments.add(
        RoutineTemplateAssignment(
          id: doc.id,
          childId: childId,
          childName: child['name'] as String,
          childAvatarTone: child['avatarTone'] as String?,
          childPhotoUrl: child['photoUrl'] as String?,
        ),
      );
    }

    return RoutineTemplate(
      id: snapshot.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      frequency: data['frequency'] as String? ?? 'DAILY',
      daysOfWeek: (data['daysOfWeek'] as List<dynamic>?)?.cast<String>(),
      rewardNote: data['rewardNote'] as String?,
      items: items.docs
          .map(
            (doc) => RoutineTemplateItem(
              id: doc.id,
              title: doc.data()['title'] as String,
              description: doc.data()['description'] as String?,
              icon: doc.data()['icon'] as String?,
              points: doc.data()['points'] as num? ?? 1,
              reminderStyle:
                  doc.data()['reminderStyle'] as String? ?? 'FRIENDLY',
            ),
          )
          .toList(),
      assignments: assignments,
    );
  }

  Map<String, dynamic> _taskFromItem({
    required Map<String, dynamic> item,
    required String templateId,
    required String? frequency,
    required List<dynamic>? daysOfWeek,
  }) => {
    'title': item['title'] ?? 'Task',
    'description': item['description'],
    'icon': item['icon'],
    'reminderStyle': item['reminderStyle'] ?? 'FRIENDLY',
    'frequency': frequency ?? 'DAILY',
    'daysOfWeek': daysOfWeek,
    'points': item['points'] ?? 1,
    'active': true,
    'createdById': _currentUser.uid,
    'routineTemplateId': templateId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  Future<List<RoutineTemplate>> fetchRoutineTemplates(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final templates = await _routineTemplates(familyId).get();
        final result = <RoutineTemplate>[];
        for (final doc in templates.docs) {
          result.add(await _loadRoutineTemplate(familyId, doc));
        }
        return result;
      });

  /// Real-time stream of routine templates that auto-updates when Firestore changes.
  Stream<List<RoutineTemplate>> watchRoutineTemplates() async* {
    final familyId = await _myFamilyId();
    yield await fetchRoutineTemplates('');

    await for (final _ in _routineTemplates(familyId).snapshots()) {
      try {
        yield await fetchRoutineTemplates('');
      } catch (_) {
        // preserve previous state
      }
    }
  }

  @override
  Future<RoutineTemplate> fetchRoutineTemplateDetail(
    String token,
    String templateId,
  ) => _guard(() async {
    final familyId = await _myFamilyId();
    final snapshot = await _routineTemplates(familyId).doc(templateId).get();
    return _loadRoutineTemplate(familyId, snapshot);
  });

  @override
  Future<String?> createRoutineTemplate(
    String token, {
    required String name,
    required List<Map<String, dynamic>> items,
    String? description,
    String? frequency,
    List<String>? daysOfWeek,
    String? rewardNote,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final ref = _routineTemplates(familyId).doc();

    final batch = _db.batch();
    batch.set(ref, {
      'name': name,
      'description': description,
      'frequency': frequency ?? 'DAILY',
      'daysOfWeek': daysOfWeek,
      'rewardNote': rewardNote,
      'createdById': _currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    for (final item in items) {
      batch.set(ref.collection('items').doc(), {
        'title': item['title'] ?? 'Task',
        'description': item['description'],
        'icon': item['icon'],
        'points': item['points'] ?? 1,
        'reminderStyle': item['reminderStyle'] ?? 'FRIENDLY',
      });
    }
    await batch.commit();
    return ref.id;
  });

  /// Assigning materialises one task per template item, exactly as the
  /// $transaction in api/src/routes/routines.ts did.
  @override
  Future<void> assignRoutineTemplate(
    String token,
    String templateId,
    String childId,
  ) => _guard(() async {
    final familyId = await _myFamilyId();
    final snapshot = await _routineTemplates(familyId).doc(templateId).get();
    final template = snapshot.data();
    if (template == null) throw ApiException('Template not found');

    final items = await snapshot.reference.collection('items').get();

    final batch = _db.batch();
    for (final item in items.docs) {
      final taskRef = _tasks(familyId).doc();
      batch.set(
        taskRef,
        _taskFromItem(
          item: item.data(),
          templateId: templateId,
          frequency: template['frequency'] as String?,
          daysOfWeek: template['daysOfWeek'] as List<dynamic>?,
        ),
      );
      batch.set(_taskAssignments(familyId).doc(_assignmentId(taskRef.id, childId)), {
        'taskId': taskRef.id,
        'childId': childId,
        'assignedAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(_routineAssignments(familyId).doc('${templateId}_$childId'), {
      'templateId': templateId,
      'childId': childId,
      'assignedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  });

  /// Editing a template rebuilds the tasks it generated, matching the
  /// delete-and-recreate the Express route performed.
  @override
  Future<void> updateRoutineTemplate(
    String token,
    String templateId, {
    required List<Map<String, dynamic>> items,
    String? name,
    String? description,
    String? rewardNote,
    String? frequency,
    List<String>? daysOfWeek,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final templateRef = _routineTemplates(familyId).doc(templateId);
    final template = (await templateRef.get()).data();
    if (template == null) throw ApiException('Template not found');

    final effectiveFrequency =
        frequency ?? template['frequency'] as String? ?? 'DAILY';
    final effectiveDays = daysOfWeek ?? template['daysOfWeek'] as List<dynamic>?;

    final oldItems = await templateRef.collection('items').get();
    final oldTasks = await _tasks(
      familyId,
    ).where('routineTemplateId', isEqualTo: templateId).get();
    final assignments = await _routineAssignments(
      familyId,
    ).where('templateId', isEqualTo: templateId).get();

    final batch = _db.batch();
    batch.update(templateRef, {
      'name': ?name,
      'description': ?description,
      'rewardNote': ?rewardNote,
      'frequency': effectiveFrequency,
      'daysOfWeek': effectiveDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final doc in oldItems.docs) {
      batch.delete(doc.reference);
    }
    for (final item in items) {
      batch.set(templateRef.collection('items').doc(), {
        'title': item['title'] ?? 'Task',
        'description': item['description'],
        'icon': item['icon'],
        'points': item['points'] ?? 1,
        'reminderStyle': item['reminderStyle'] ?? 'FRIENDLY',
      });
    }

    await _deleteGeneratedTasks(familyId, oldTasks.docs, batch);

    for (final assignment in assignments.docs) {
      final childId = assignment.data()['childId'] as String;
      for (final item in items) {
        final taskRef = _tasks(familyId).doc();
        batch.set(
          taskRef,
          _taskFromItem(
            item: item,
            templateId: templateId,
            frequency: effectiveFrequency,
            daysOfWeek: effectiveDays,
          ),
        );
        batch.set(
          _taskAssignments(familyId).doc(_assignmentId(taskRef.id, childId)),
          {
            'taskId': taskRef.id,
            'childId': childId,
            'assignedAt': FieldValue.serverTimestamp(),
          },
        );
      }
    }

    await batch.commit();
  });

  /// Batches cap at 500 writes; a family large enough to exceed that would
  /// need chunking here (FIREBASE_MIGRATION_PLAN.md §7).
  Future<void> _deleteGeneratedTasks(
    String familyId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
    WriteBatch batch,
  ) async {
    for (final task in tasks) {
      final completions = await task.reference.collection('completions').get();
      for (final doc in completions.docs) {
        batch.delete(doc.reference);
      }
      final assignments = await _taskAssignments(
        familyId,
      ).where('taskId', isEqualTo: task.id).get();
      for (final doc in assignments.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(task.reference);
    }
  }

  @override
  Future<void> deleteRoutineTemplate(String token, String templateId) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final templateRef = _routineTemplates(familyId).doc(templateId);
        final items = await templateRef.collection('items').get();
        final tasks = await _tasks(
          familyId,
        ).where('routineTemplateId', isEqualTo: templateId).get();
        final assignments = await _routineAssignments(
          familyId,
        ).where('templateId', isEqualTo: templateId).get();

        final batch = _db.batch();
        for (final doc in items.docs) {
          batch.delete(doc.reference);
        }
        for (final doc in assignments.docs) {
          batch.delete(doc.reference);
        }
        await _deleteGeneratedTasks(familyId, tasks.docs, batch);
        batch.delete(templateRef);
        await batch.commit();
        await _notifyCompletionChange(familyId);
      });

  @override
  Future<void> unassignRoutineTemplate(
    String token,
    String templateId,
    String childId,
  ) => _guard(() async {
    final familyId = await _myFamilyId();
    final tasks = await _tasks(
      familyId,
    ).where('routineTemplateId', isEqualTo: templateId).get();

    final batch = _db.batch();
    for (final task in tasks.docs) {
      final assignmentRef = _taskAssignments(
        familyId,
      ).doc(_assignmentId(task.id, childId));
      if (!(await assignmentRef.get()).exists) continue;
      batch.delete(assignmentRef);

      final completions = await task.reference
          .collection('completions')
          .where('childId', isEqualTo: childId)
          .get();
      for (final doc in completions.docs) {
        batch.delete(doc.reference);
      }

      // The generated task only exists for its assignees, so drop it once
      // this was the last one.
      final remaining = await _taskAssignments(
        familyId,
      ).where('taskId', isEqualTo: task.id).get();
      if (remaining.docs.every((doc) => doc.id == assignmentRef.id)) {
        batch.delete(task.reference);
      }
    }
    batch.delete(_routineAssignments(familyId).doc('${templateId}_$childId'));
    await batch.commit();
    await _notifyCompletionChange(familyId, null, childId);
  });

  // ---- Points ----

  Future<PointEntry> _toPointEntry(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool includeChild,
  }) async {
    final data = doc.data()!;
    final points = data['points'] as num;

    Map<String, dynamic>? child;
    if (includeChild) {
      final childId = data['childId'] as String;
      final childData = (await _users.doc(childId).get()).data();
      if (childData != null) {
        child = {
          'id': childId,
          'name': childData['name'],
          'username': childData['username'],
          'avatarTone': childData['avatarTone'],
        };
      }
    }

    Map<String, dynamic>? createdBy;
    final createdById = data['createdById'] as String?;
    if (createdById != null) {
      final creator = (await _users.doc(createdById).get()).data();
      if (creator != null) {
        createdBy = {'id': createdById, 'name': creator['name']};
      }
    }

    return PointEntry.fromJson({
      'id': doc.id,
      'type': data['type'],
      'points': points,
      'amount': points.abs(),
      'note': data['note'],
      'createdAt':
          (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ??
          DateTime.now().toIso8601String(),
      'child': child,
      'createdBy': createdBy,
    });
  }

  Future<List<PointEntry>> _mapPointEntries(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool includeChild,
  }) async {
    final entries = <PointEntry>[];
    for (final doc in docs) {
      entries.add(await _toPointEntry(doc, includeChild: includeChild));
    }
    return entries;
  }

  @override
  Future<List<PointEntry>> fetchPointEntries(
    String token, {
    String? scope,
    int? limit,
    String? childId,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final role = await _myRole();
    final targetChildId = role == 'CHILD' ? _currentUser.uid : childId;

    Query<Map<String, dynamic>> query = _pointAdjustments(familyId);
    if (targetChildId != null) {
      query = query.where('childId', isEqualTo: targetChildId);
    }

    var docs = (await query.get()).docs.toList();

    if (scope == 'today') {
      final bounds = dayBoundsForTimeZone(await _familyTimeZone(familyId));
      docs = docs.where((doc) {
        final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null &&
            !createdAt.isBefore(bounds.start) &&
            createdAt.isBefore(bounds.end);
      }).toList();
    }

    docs.sort(_byCreatedAtDesc);
    return _mapPointEntries(
      docs.take((limit ?? 10).clamp(1, 50)),
      includeChild: role == 'PARENT',
    );
  });

  @override
  Future<List<PointEntry>> fetchPointHistory(
    String token, {
    String? childId,
    int? limit,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    Query<Map<String, dynamic>> query = _pointAdjustments(familyId);
    if (childId != null) {
      query = query.where('childId', isEqualTo: childId);
    }

    final docs = (await query.get()).docs.toList()..sort(_byCreatedAtDesc);
    return _mapPointEntries(
      docs.take((limit ?? 50).clamp(1, 50)),
      includeChild: true,
    );
  });

  @override
  Future<PointEntry> createPointEntry(
    String token, {
    required String childId,
    required PointEntryType type,
    required num amount,
    String? note,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final normalized = amount.abs().truncate();
    if (normalized <= 0) {
      throw ApiException('amount must be greater than 0');
    }

    final trimmed = note?.trim();
    final ref = _pointAdjustments(familyId).doc();
    await ref.set({
      'childId': childId,
      'createdById': _currentUser.uid,
      'points': type == PointEntryType.gift ? normalized : -normalized,
      'type': pointEntryTypeToJson(type),
      'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return _toPointEntry(await ref.get(), includeChild: true);
  });

  // ---- Family overview & deletion ----

  /// Replaces the groupBy aggregation in GET /auth/family/overview. Firestore
  /// has no groupBy, so the counts are assembled here from documents already
  /// being read.
  @override
  Future<List<FamilyOverviewEntry>> fetchFamilyOverview(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final timeZone = await _familyTimeZone(familyId);
        final today = startOfDayInTimeZone(timeZone);

        final membersSnapshot = await _users
            .where('familyId', isEqualTo: familyId)
            .get();
        final memberDocs = membersSnapshot.docs.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null || bCreated == null) return 0;
            return aCreated.compareTo(bCreated);
          });
        final tasks = await _tasks(familyId).get();
        final childCount = memberDocs
            .where((doc) => doc.data()['role'] == 'CHILD')
            .length;

        final entries = <FamilyOverviewEntry>[];
        for (final member in memberDocs) {
          final data = member.data();
          final Map<String, num> stats;

          if (data['role'] == 'CHILD') {
            final progress = await _progress.childProgressSnapshot(
              familyId,
              member.id,
              timeZone,
            );
            final assignments = await _taskAssignments(
              familyId,
            ).where('childId', isEqualTo: member.id).get();

            // Firing these serially (await-in-a-loop) can stall indefinitely
            // on cloud_firestore's web plugin once enough one-shot get()
            // calls queue up on its shared channel — see
            // FIREBASE_MIGRATION_PLAN.md §7. Future.wait fires them together.
            final statuses = await Future.wait(
              tasks.docs.map(
                (task) => _progress.latestStatusForDay(
                  familyId,
                  task.id,
                  member.id,
                  today,
                ),
              ),
            );
            final completedToday = statuses
                .where((status) => status == 'COMPLETED')
                .length;

            stats = {
              'seedBalance': progress.seedBalance,
              'streak': progress.streak,
              'assignments': assignments.docs.length,
              'completedToday': completedToday,
            };
          } else {
            stats = {
              'tasksCreated': tasks.docs
                  .where((task) => task.data()['createdById'] == member.id)
                  .length,
              'kidsAssigned': childCount,
            };
          }

          entries.add(
            FamilyOverviewEntry(
              id: member.id,
              name: data['name'] as String,
              username: data['username'] as String,
              role: userRoleFromJson(data['role'] as String),
              avatarTone: data['avatarTone'] as String?,
              photoUrl: data['photoUrl'] as String?,
              email: data['email'] as String?,
              stats: stats,
            ),
          );
        }
        return entries;
      });

  /// Firestore batches cap at 500 writes, and a family cascade easily exceeds
  /// that, so deletes are committed in chunks.
  Future<void> _deleteInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(chunkSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> deleteFamilyAccount(String token) => _guard(() async {
    final familyId = await _myFamilyId();
    final uid = _currentUser.uid;
    final refs = <DocumentReference<Map<String, dynamic>>>[];

    final tasks = await _tasks(familyId).get();
    for (final task in tasks.docs) {
      final completions = await task.reference.collection('completions').get();
      refs.addAll(completions.docs.map((doc) => doc.reference));
      refs.add(task.reference);
    }

    final templates = await _routineTemplates(familyId).get();
    for (final template in templates.docs) {
      final items = await template.reference.collection('items').get();
      refs.addAll(items.docs.map((doc) => doc.reference));
      refs.add(template.reference);
    }

    final missions = await _family(familyId).collection('teamMissions').get();
    for (final mission in missions.docs) {
      for (final name in ['participants', 'rewards']) {
        final docs = await mission.reference.collection(name).get();
        refs.addAll(docs.docs.map((doc) => doc.reference));
      }
      refs.add(mission.reference);
    }

    for (final name in [
      'taskAssignments',
      'routineAssignments',
      'rewardDefinitions',
      'rewardRedemptions',
      'privilegeDefinitions',
      'privilegeRequests',
      'pointAdjustments',
      'streakRewardLogs',
      'nudgeSettings',
      'notes',
    ]) {
      final docs = await _family(familyId).collection(name).get();
      refs.addAll(docs.docs.map((doc) => doc.reference));
    }

    final members = await _users.where('familyId', isEqualTo: familyId).get();

    // Usernames before user documents: releasing someone else's username is
    // only permitted while their user document still says they are family.
    for (final member in members.docs) {
      final username = member.data()['username'] as String?;
      if (username != null) refs.add(_usernames.doc(username));
    }
    for (final member in members.docs) {
      if (member.id != uid) refs.add(member.reference);
    }

    await _deleteInChunks(refs);

    // The caller's own user document goes last: every rule resolves the
    // caller's role through get(users/{uid}), so deleting it earlier would
    // deny everything that follows. The family document goes second-to-last
    // for the same reason it went last in the Express cascade — while it
    // still resolves, an interrupted delete can simply be retried.
    await _family(familyId).delete();
    await _users.doc(uid).delete();

    // Auth accounts survive this; removing them needs the Admin SDK. With
    // the user documents gone every rule fails closed. See §7 of the plan.
  });

  // ---- Privileges ----

  CollectionReference<Map<String, dynamic>> _privilegeDefinitions(
    String familyId,
  ) => _family(familyId).collection('privilegeDefinitions');

  CollectionReference<Map<String, dynamic>> _privilegeRequests(
    String familyId,
  ) => _family(familyId).collection('privilegeRequests');

  String _isoOrNow(Object? value) =>
      (value as Timestamp?)?.toDate().toIso8601String() ??
      DateTime.now().toIso8601String();

  Map<String, dynamic> _privilegeJson(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return {
      'id': doc.id,
      'title': data['title'],
      'description': data['description'],
      'cost': data['cost'],
      'createdAt': _isoOrNow(data['createdAt']),
    };
  }

  Future<PrivilegeRequestEntry> _toRequestEntry(
    String familyId,
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool includeChild,
  }) async {
    final data = doc.data()!;
    final privilegeId = data['privilegeId'] as String;
    final definition = await _privilegeDefinitions(familyId)
        .doc(privilegeId)
        .get();

    Map<String, dynamic>? child;
    if (includeChild) {
      final childId = data['childId'] as String;
      final childData = (await _users.doc(childId).get()).data();
      if (childData != null) {
        child = {
          'id': childId,
          'name': childData['name'],
          'avatarTone': childData['avatarTone'],
        };
      }
    }

    return PrivilegeRequestEntry.fromJson({
      'id': doc.id,
      'privilegeId': privilegeId,
      // The definition can be gone if a parent deleted it; the model needs
      // one regardless, so fall back to the cost frozen on the request.
      'privilege': definition.exists
          ? _privilegeJson(definition)
          : {
              'id': privilegeId,
              'title': data['customTitle'] ?? data['title'] ?? 'Custom Privilege',
              'description': data['customDescription'] ?? data['description'],
              'cost': data['cost'],
              'createdAt': _isoOrNow(data['createdAt']),
            },
      'childId': data['childId'],
      'status': data['status'],
      'note': data['note'],
      'cost': data['cost'],
      'createdAt': _isoOrNow(data['createdAt']),
      'resolvedAt': (data['resolvedAt'] as Timestamp?)
          ?.toDate()
          .toIso8601String(),
      'child': child,
    });
  }

  @override
  Future<List<PrivilegeDefinition>> fetchPrivileges(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final snapshot = await _privilegeDefinitions(familyId).get();
        final docs = snapshot.docs.toList()..sort(_byCreatedAtDesc);
        return docs.reversed
            .map((doc) => PrivilegeDefinition.fromJson(_privilegeJson(doc)))
            .toList();
      });

  @override
  Future<PrivilegeDefinition> createPrivilege(
    String token, {
    required String title,
    required num cost,
    String? description,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final ref = _privilegeDefinitions(familyId).doc();
    await ref.set({
      'title': title,
      'description': description,
      'cost': cost < 1 ? 1 : cost,
      'createdById': _currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return PrivilegeDefinition.fromJson(_privilegeJson(await ref.get()));
  });

  @override
  Future<PrivilegeDefinition> updatePrivilege(
    String token,
    String privilegeId, {
    String? title,
    String? description,
    num? cost,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final ref = _privilegeDefinitions(familyId).doc(privilegeId);
    await ref.update({
      'title': ?title,
      'description': ?description,
      if (cost != null) 'cost': cost < 1 ? 1 : cost,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return PrivilegeDefinition.fromJson(_privilegeJson(await ref.get()));
  });

  @override
  Future<void> deletePrivilege(String token, String privilegeId) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        final requests = await _privilegeRequests(
          familyId,
        ).where('privilegeId', isEqualTo: privilegeId).get();

        final batch = _db.batch();
        for (final doc in requests.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(_privilegeDefinitions(familyId).doc(privilegeId));
        await batch.commit();
      });

  @override
  Future<PrivilegeRequestEntry> requestPrivilege(
    String token,
    String privilegeId,
  ) => _guard(() async {
    final familyId = await _myFamilyId();
    final uid = _currentUser.uid;
    final definition = (await _privilegeDefinitions(
      familyId,
    ).doc(privilegeId).get()).data();
    if (definition == null) throw ApiException('Privilege not found');

    final existing = await _privilegeRequests(familyId)
        .where('childId', isEqualTo: uid)
        .where('privilegeId', isEqualTo: privilegeId)
        .where('status', isEqualTo: 'PENDING')
        .get();
    if (existing.docs.isNotEmpty) {
      throw ApiException('Request already pending');
    }

    final cost = definition['cost'] as num;
    // Advisory only: the rules pin the cost but cannot sum a balance, so this
    // check lives in the client. See FIREBASE_MIGRATION_PLAN.md §7.
    final balance = await _progress.calculateSeedBalance(familyId, uid);
    if (balance < cost) {
      throw ApiException('Not enough seeds to request this privilege');
    }

    final ref = _privilegeRequests(familyId).doc();
    await ref.set({
      'privilegeId': privilegeId,
      'childId': uid,
      'cost': cost,
      'status': 'PENDING',
      'note': null,
      'resolvedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return _toRequestEntry(familyId, await ref.get(), includeChild: true);
  });

  @override
  Future<PrivilegeRequestEntry> requestCustomPrivilege(
    String token, {
    required String title,
    required num cost,
    String? note,
  }) => _guard(() async {
    final familyId = await _myFamilyId();
    final uid = _currentUser.uid;
    final balance = await _progress.calculateSeedBalance(familyId, uid);
    final validatedCost = cost < 1 ? 1 : cost;
    if (balance < validatedCost) {
      throw ApiException('Not enough seeds to request this privilege');
    }

    final ref = _privilegeRequests(familyId).doc();
    await ref.set({
      'privilegeId': 'custom_${ref.id}',
      'customTitle': title.trim(),
      'childId': uid,
      'cost': validatedCost,
      'status': 'PENDING',
      'note': note?.trim(),
      'resolvedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return _toRequestEntry(familyId, await ref.get(), includeChild: true);
  });

  Future<List<PrivilegeRequestEntry>> _loadRequests(
    String familyId,
    Query<Map<String, dynamic>> query, {
    required bool includeChild,
  }) async {
    final docs = (await query.get()).docs.toList()..sort(_byCreatedAtDesc);
    final entries = <PrivilegeRequestEntry>[];
    for (final doc in docs) {
      entries.add(
        await _toRequestEntry(familyId, doc, includeChild: includeChild),
      );
    }
    return entries;
  }

  @override
  Future<List<PrivilegeRequestEntry>> fetchPrivilegeRequests(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        return _loadRequests(
          familyId,
          _privilegeRequests(familyId),
          includeChild: true,
        );
      });

  @override
  Future<List<PrivilegeRequestEntry>> fetchMyPrivilegeRequests(String token) =>
      _guard(() async {
        final familyId = await _myFamilyId();
        return _loadRequests(
          familyId,
          _privilegeRequests(
            familyId,
          ).where('childId', isEqualTo: _currentUser.uid),
          includeChild: false,
        );
      });

  /// Real-time stream of all privilege requests in the family.
  Stream<List<PrivilegeRequestEntry>> watchPrivilegeRequests() async* {
    final familyId = await _myFamilyId();
    yield await fetchPrivilegeRequests('');

    await for (final _ in _privilegeRequests(familyId).snapshots()) {
      try {
        yield await fetchPrivilegeRequests('');
      } catch (_) {
        // preserve previous state on transient errors
      }
    }
  }

  /// Real-time stream of the current child's privilege requests.
  Stream<List<PrivilegeRequestEntry>> watchMyPrivilegeRequests() async* {
    final familyId = await _myFamilyId();
    yield await fetchMyPrivilegeRequests('');

    final query = _privilegeRequests(familyId)
        .where('childId', isEqualTo: _currentUser.uid);

    await for (final _ in query.snapshots()) {
      try {
        yield await fetchMyPrivilegeRequests('');
      } catch (_) {
        // preserve previous state on transient errors
      }
    }
  }

  /// Real-time stream of the child's seed balance that automatically recomputes
  /// whenever relevant Firestore collections (privilege requests, point adjustments,
  /// streak reward logs, or tasks/completions) change.
  Stream<int> watchChildSeedBalance([String? childId]) {
    late final StreamController<int> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    Future<void> emitBalance(String familyId, String targetUid) async {
      try {
        final balance = await _progress.calculateSeedBalance(familyId, targetUid);
        if (!controller.isClosed) {
          controller.add(balance);
        }
      } catch (e) {
        debugPrint('watchChildSeedBalance error: $e');
      }
    }

    controller = StreamController<int>(
      onListen: () async {
        try {
          final familyId = await _myFamilyId();
          final targetUid = childId ?? _currentUser.uid;

          // Initial push
          await emitBalance(familyId, targetUid);

          // Watch privilege requests for this child
          subscriptions.add(
            _privilegeRequests(familyId)
                .where('childId', isEqualTo: targetUid)
                .snapshots()
                .listen((_) => emitBalance(familyId, targetUid)),
          );

          // Watch point adjustments for this child
          subscriptions.add(
            _pointAdjustments(familyId)
                .where('childId', isEqualTo: targetUid)
                .snapshots()
                .listen((_) => emitBalance(familyId, targetUid)),
          );

          // Watch streak reward logs for this child
          subscriptions.add(
            _streakRewardLogs(familyId)
                .where('childId', isEqualTo: targetUid)
                .snapshots()
                .listen((_) => emitBalance(familyId, targetUid)),
          );

          // Watch task collection for task list changes
          subscriptions.add(
            _tasks(familyId)
                .snapshots()
                .listen((_) => emitBalance(familyId, targetUid)),
          );

          // Watch task completion events
          subscriptions.add(
            _taskCompletions(familyId)
                .snapshots()
                .listen((_) => emitBalance(familyId, targetUid)),
          );
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  /// Real-time stream of the family overview (members and their stats) that
  /// automatically updates whenever tasks, completions, privileges, points,
  /// streak logs, or family members change.
  Stream<List<FamilyOverviewEntry>> watchFamilyOverview() {
    late final StreamController<List<FamilyOverviewEntry>> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    Future<void> emitOverview() async {
      try {
        final overview = await fetchFamilyOverview('');
        if (!controller.isClosed) {
          controller.add(overview);
        }
      } catch (e) {
        debugPrint('watchFamilyOverview error: $e');
      }
    }

    controller = StreamController<List<FamilyOverviewEntry>>(
      onListen: () async {
        try {
          final familyId = await _myFamilyId();
          await emitOverview();

          subscriptions.add(
            _users
                .where('familyId', isEqualTo: familyId)
                .snapshots()
                .listen((_) => emitOverview()),
          );
          subscriptions.add(
            _tasks(familyId).snapshots().listen((_) => emitOverview()),
          );
          subscriptions.add(
            _taskAssignments(familyId).snapshots().listen((_) => emitOverview()),
          );
          subscriptions.add(
            _taskCompletions(familyId).snapshots().listen((_) => emitOverview()),
          );
          subscriptions.add(
            _privilegeRequests(familyId).snapshots().listen((_) => emitOverview()),
          );
          subscriptions.add(
            _pointAdjustments(familyId).snapshots().listen((_) => emitOverview()),
          );
          subscriptions.add(
            _streakRewardLogs(familyId).snapshots().listen((_) => emitOverview()),
          );
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  Future<PrivilegeRequestEntry> _resolveRequest(
    String requestId, {
    required String status,
    required String expectedCurrentStatus,
    required String wrongStatusMessage,
    String? note,
  }) async {
    final familyId = await _myFamilyId();
    final ref = _privilegeRequests(familyId).doc(requestId);
    final request = (await ref.get()).data();
    if (request == null) throw ApiException('Request not found');
    if (request['status'] != expectedCurrentStatus) {
      throw ApiException(wrongStatusMessage);
    }

    if (status == 'APPROVED') {
      final childId = request['childId'] as String;
      final balance = await _progress.calculateSeedBalance(familyId, childId);
      if (balance < (request['cost'] as num)) {
        throw ApiException('Child does not have enough seeds anymore');
      }
    }

    // childId and cost are frozen by the rules, so approving cannot quietly
    // reprice the request.
    await ref.update({
      'status': status,
      'note': ?note,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    return _toRequestEntry(familyId, await ref.get(), includeChild: true);
  }

  @override
  Future<PrivilegeRequestEntry> decidePrivilegeRequest(
    String token,
    String requestId, {
    required bool approve,
    String? note,
  }) => _guard(
    () => _resolveRequest(
      requestId,
      status: approve ? 'APPROVED' : 'REJECTED',
      expectedCurrentStatus: 'PENDING',
      wrongStatusMessage: 'Request already processed',
      note: note,
    ),
  );

  @override
  Future<PrivilegeRequestEntry> terminatePrivilegeRequest(
    String token,
    String requestId, {
    String? note,
  }) => _guard(
    () => _resolveRequest(
      requestId,
      status: 'TERMINATED',
      expectedCurrentStatus: 'APPROVED',
      wrongStatusMessage: 'Only approved tickets can be terminated',
      note: note,
    ),
  );

  // ---- Nudges ----
  //
  // One document per child holding a map of type -> setting, which fits the
  // parent-only nudgeSettings rule. The Express API wrote defaults into the
  // database on first read; here an unset type simply falls back to the
  // template, because a child reading their own nudges cannot write.

  CollectionReference<Map<String, dynamic>> _nudgeSettings(String familyId) =>
      _family(familyId).collection('nudgeSettings');

  List<NudgeSetting> _nudgesFor(
    String childId,
    Map<String, dynamic>? stored, {
    String? childName,
    String? childAvatarTone,
  }) {
    final updatedAt = _isoOrNow(stored?['updatedAt']);
    return defaultNudgeTemplates.map((template) {
      final type = template['type']!;
      final saved = stored?[type] as Map<String, dynamic>?;
      return NudgeSetting(
        id: '${childId}_$type',
        childId: childId,
        childName: childName,
        childAvatarTone: childAvatarTone,
        type: type,
        label: template['label']!,
        time: saved?['time'] as String? ?? template['time']!,
        message: saved?['message'] as String? ?? template['message'],
        enabled: saved?['enabled'] as bool? ?? true,
        updatedAt: updatedAt,
      );
    }).toList();
  }

  @override
  Future<List<NudgeSetting>> fetchNudges(String token, {String? childId}) =>
      _guard(() async {
        final familyId = await _myFamilyId();

        if (await _myRole() == 'CHILD') {
          final uid = _currentUser.uid;
          final stored = (await _nudgeSettings(familyId).doc(uid).get()).data();
          return _nudgesFor(uid, stored);
        }

        final membersSnapshot = await _users
            .where('familyId', isEqualTo: familyId)
            .get();
        final children = membersSnapshot.docs
            .where((doc) => doc.data()['role'] == 'CHILD')
            .toList();

        final settings = <NudgeSetting>[];
        for (final child in children) {
          if (childId != null && child.id != childId) continue;
          final stored = (await _nudgeSettings(familyId).doc(child.id).get())
              .data();
          settings.addAll(
            _nudgesFor(
              child.id,
              stored,
              childName: child.data()['name'] as String?,
              childAvatarTone: child.data()['avatarTone'] as String?,
            ),
          );
        }
        return settings;
      });

  @override
  Future<List<NudgeSetting>> updateNudges(
    String token,
    String childId,
    List<NudgeUpdateItem> nudges,
  ) => _guard(() async {
    final familyId = await _myFamilyId();
    final allowed = defaultNudgeTemplates
        .map((template) => template['type'])
        .toSet();

    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    for (final nudge in nudges) {
      if (!allowed.contains(nudge.type)) {
        throw ApiException('Unsupported nudge type: ${nudge.type}');
      }
      final time = _normalizeTime(nudge.time);
      if (time == null) continue;
      final message = nudge.message?.trim();
      updates[nudge.type] = {
        'time': time,
        'enabled': nudge.enabled,
        'message': (message == null || message.isEmpty) ? null : message,
      };
    }

    if (updates.length == 1) {
      throw ApiException('At least one valid nudge update is required');
    }

    final ref = _nudgeSettings(familyId).doc(childId);
    await ref.set(updates, SetOptions(merge: true));

    final child = (await _users.doc(childId).get()).data();
    return _nudgesFor(
      childId,
      (await ref.get()).data(),
      childName: child?['name'] as String?,
      childAvatarTone: child?['avatarTone'] as String?,
    );
  });

  static final RegExp _timePattern = RegExp(r'^(\d{1,2}):([0-5]\d)$');

  String? _normalizeTime(String value) {
    final match = _timePattern.firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    if (hour > 23) return null;
    return '${hour.toString().padLeft(2, '0')}:${match.group(2)}';
  }
}
