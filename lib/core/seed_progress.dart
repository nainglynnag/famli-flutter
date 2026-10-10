import 'package:cloud_firestore/cloud_firestore.dart';

import 'family_time.dart';

class StreakInfo {
  StreakInfo({required this.count, this.startDate});

  final int count;
  final DateTime? startDate;
}

class ChildProgress {
  ChildProgress({required this.seedBalance, required this.streak});

  final int seedBalance;
  final int streak;
}

class TaskStatusResult {
  const TaskStatusResult({required this.status, required this.isApplicable});

  final String status;
  final bool isApplicable;
}

/// Ports api/src/services/progress.ts as a read-time computation.
///
/// Nothing here is stored: seed balance and streak are recomputed from the
/// underlying completions, adjustments and streak logs on every read, so there
/// is no balance field for a modified client to write. That is the whole point
/// of the no-Cloud-Functions design — see FIREBASE_MIGRATION_PLAN.md §3.
///
/// Reward redemptions, privilege costs and mission bonuses are part of the
/// balance in the Express version but are not subtracted here yet: those
/// collections have no writer until Phase 3, so they are always empty.
class SeedProgress {
  SeedProgress(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _family(String familyId) =>
      _db.collection('families').doc(familyId);

  /// Every COMPLETED completion for [childId] across every task in the family.
  ///
  /// Deliberately not a collection-group query: those need composite indexes
  /// deployed ahead of time, and a family's task list is small enough that the
  /// extra reads are cheaper than the operational overhead.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _completions(
    String familyId,
    String childId,
  ) async {
    final tasks = await _family(familyId).collection('tasks').get();
    final results = await Future.wait(
      tasks.docs.map(
        (task) => task.reference
            .collection('completions')
            .where('childId', isEqualTo: childId)
            .get(),
      ),
    );
    return results
        .expand((snapshot) => snapshot.docs)
        .where((doc) => doc.data()['status'] == 'COMPLETED')
        .toList();
  }

  num _sumField(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String field,
  ) => docs.fold<num>(
    0,
    (total, doc) => total + (doc.data()[field] as num? ?? 0),
  );

  Future<int> calculateSeedBalance(String familyId, String childId) async {
    final completions = await _completions(familyId, childId);

    final adjustments = await _family(familyId)
        .collection('pointAdjustments')
        .where('childId', isEqualTo: childId)
        .get();

    final streakLogs = await _family(familyId)
        .collection('streakRewardLogs')
        .where('childId', isEqualTo: childId)
        .get();

    final privilegeDocs = await _family(familyId)
        .collection('privilegeRequests')
        .where('childId', isEqualTo: childId)
        .get();

    final spentOnPrivileges = privilegeDocs.docs
        .where((doc) {
          final s = doc.data()['status'] as String?;
          return s == 'APPROVED' || s == 'TERMINATED';
        })
        .fold<num>(0, (total, doc) => total + (doc.data()['cost'] as num? ?? 0));

    // pointAdjustments already carry their sign (a PENALTY is negative).
    final total =
        _sumField(completions, 'seedsEarned') +
        _sumField(adjustments.docs, 'points') +
        _sumField(streakLogs.docs, 'seedsEarned') -
        spentOnPrivileges;

    return total.round().clamp(0, 999999);
  }

  Future<StreakInfo> calculateChildStreak(
    String familyId,
    String childId,
    String timeZone,
  ) async {
    final today = startOfDayInTimeZone(timeZone);
    final todayMs = today.millisecondsSinceEpoch;
    const dayMs = 24 * 60 * 60 * 1000;

    // A day is marked complete if a DAILY streakRewardLog exists for it.
    final streakLogs = await _family(familyId)
        .collection('streakRewardLogs')
        .where('childId', isEqualTo: childId)
        .get();

    final completedDays = <int>{};
    for (final doc in streakLogs.docs) {
      if (doc.data()['period'] != 'DAILY') continue;
      // Doc id format is: ${childId}_DAILY_${dayKey}
      final parts = doc.id.split('_DAILY_');
      if (parts.length == 2 && parts[1].length == 8) {
        final keyStr = parts[1];
        final year = int.tryParse(keyStr.substring(0, 4));
        final month = int.tryParse(keyStr.substring(4, 6));
        final day = int.tryParse(keyStr.substring(6, 8));
        if (year != null && month != null && day != null) {
          completedDays.add(DateTime.utc(year, month, day).millisecondsSinceEpoch);
        }
      }
    }

    // Also check if today is completed right now in real time
    var todayComplete = completedDays.contains(todayMs);
    if (!todayComplete) {
      final dueToday = await _tasksDueToday(familyId, childId, timeZone);
      if (dueToday.isNotEmpty) {
        final statuses = await Future.wait(
          dueToday.map((taskId) => latestStatusForDay(familyId, taskId, childId, today)),
        );
        if (statuses.every((status) => status == 'COMPLETED')) {
          todayComplete = true;
          completedDays.add(todayMs);
        }
      }
    }

    var streak = 0;
    // If today is complete, we walk backward starting from today.
    // If today is not complete yet, we walk backward starting from yesterday
    // so an intact streak is preserved while the child works on today's tasks.
    var cursor = todayComplete ? todayMs : (todayMs - dayMs);
    DateTime? streakStart;

    while (completedDays.contains(cursor)) {
      streak += 1;
      streakStart = DateTime.fromMillisecondsSinceEpoch(cursor, isUtc: true);
      cursor -= dayMs;
    }

    return StreakInfo(count: streak, startDate: streakStart);
  }

  /// Ports maybeAwardStreakRewards. Called after a task is completed.
  ///
  /// The document id is deterministic and the rules only allow creates, so
  /// awarding twice for the same period is a failed write rather than double
  /// seeds — the same uniqueness trick the usernames collection uses.
  Future<void> maybeAwardStreakRewards(
    String familyId,
    String childId,
    String timeZone,
  ) async {
    final family = (await _family(familyId).get()).data();
    if (family == null) return;

    await _maybeAwardDailyReward(familyId, childId, timeZone, family);

    final streak = await calculateChildStreak(familyId, childId, timeZone);
    if (streak.count == 0 || streak.startDate == null) return;

    final startDay = dayKey(streak.startDate!);

    // Weekly: threshold 7. Cycle key: ${startDay}_w${streak.count ~/ 7}
    final weeklyAmount = (family['weeklyStreakReward'] as num?)?.toInt() ?? 0;
    if (weeklyAmount > 0 && streak.count >= 7 && streak.count % 7 == 0) {
      final cycle = streak.count ~/ 7;
      await _award(
        familyId: familyId,
        childId: childId,
        period: 'WEEKLY',
        key: '${startDay}_w$cycle',
        streakValue: streak.count,
        amount: weeklyAmount,
      );
    }

    // Monthly: threshold 31. Cycle key: ${startDay}_m${streak.count ~/ 31}
    final monthlyAmount = (family['monthlyStreakReward'] as num?)?.toInt() ?? 0;
    if (monthlyAmount > 0 && streak.count >= 31 && streak.count % 31 == 0) {
      final cycle = streak.count ~/ 31;
      await _award(
        familyId: familyId,
        childId: childId,
        period: 'MONTHLY',
        key: '${startDay}_m$cycle',
        streakValue: streak.count,
        amount: monthlyAmount,
      );
    }

    // Yearly: threshold 365. Cycle key: ${startDay}_y${streak.count ~/ 365}
    final yearlyAmount = (family['yearlyStreakReward'] as num?)?.toInt() ?? 0;
    if (yearlyAmount > 0 && streak.count >= 365 && streak.count % 365 == 0) {
      final cycle = streak.count ~/ 365;
      await _award(
        familyId: familyId,
        childId: childId,
        period: 'YEARLY',
        key: '${startDay}_y$cycle',
        streakValue: streak.count,
        amount: yearlyAmount,
      );
    }
  }

  Future<void> _maybeAwardDailyReward(
    String familyId,
    String childId,
    String timeZone,
    Map<String, dynamic> family,
  ) async {
    final amount = (family['dailyStreakReward'] as num?)?.toInt() ?? 0;

    final today = startOfDayInTimeZone(timeZone);
    final dueToday = await _tasksDueToday(familyId, childId, timeZone);
    if (dueToday.isEmpty) return;

    final statuses = await Future.wait(
      dueToday.map((taskId) => latestStatusForDay(familyId, taskId, childId, today)),
    );
    if (statuses.any((status) => status != 'COMPLETED')) return;

    await _award(
      familyId: familyId,
      childId: childId,
      period: 'DAILY',
      key: dayKey(today),
      streakValue: dueToday.length,
      amount: amount > 0 ? amount : 0,
    );
  }

  /// Ports maybeRevokeDailyReward: undoing a task takes the day's bonus back.
  Future<void> maybeRevokeDailyReward(
    String familyId,
    String childId,
    String timeZone,
  ) async {
    final today = startOfDayInTimeZone(timeZone);
    final dueToday = await _tasksDueToday(familyId, childId, timeZone);

    final statuses = await Future.wait(
      dueToday.map((taskId) => latestStatusForDay(familyId, taskId, childId, today)),
    );
    final allDone =
        dueToday.isNotEmpty && statuses.every((status) => status == 'COMPLETED');
    if (allDone) return;

    await _family(familyId)
        .collection('streakRewardLogs')
        .doc('${childId}_DAILY_${dayKey(today)}')
        .delete();
  }

  Future<TaskStatusResult> evaluateTaskForChild({
    required String familyId,
    required String taskId,
    required Map<String, dynamic> taskData,
    required String childId,
    required DateTime today,
    required String todayKey,
  }) async {
    if (taskData['active'] != true) {
      return const TaskStatusResult(status: 'PENDING', isApplicable: false);
    }

    final isRoutine = taskData['routineTemplateId'] != null;

    if (isRoutine) {
      final activeToday = isActiveOnDay(
        taskData['daysOfWeek'] as List<dynamic>?,
        todayKey,
      );
      if (!activeToday) {
        return const TaskStatusResult(status: 'PENDING', isApplicable: false);
      }

      final todayStatus =
          await latestStatusForDay(familyId, taskId, childId, today);
      return TaskStatusResult(
        status: todayStatus ?? 'PENDING',
        isApplicable: true,
      );
    }

    // Standalone (one-time) task
    final snapshot = await _family(familyId)
        .collection('tasks')
        .doc(taskId)
        .collection('completions')
        .where('childId', isEqualTo: childId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final at =
              (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bt =
              (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });

      final latest = docs.first.data();
      final latestStatus = latest['status'] as String?;
      final latestDate = latest['date'] as Timestamp?;
      final todayTs = Timestamp.fromDate(today);

      if (latestStatus == 'COMPLETED') {
        if (latestDate != null && latestDate.compareTo(todayTs) >= 0) {
          // Completed today
          return const TaskStatusResult(status: 'COMPLETED', isApplicable: true);
        } else {
          // Completed on a previous day - do not recur
          return const TaskStatusResult(status: 'COMPLETED', isApplicable: false);
        }
      }
    }

    // Not completed yet (or latest status was undone to PENDING).
    // It remains applicable today! Check if overdue:
    final dueAt = (taskData['dueAt'] as Timestamp?)?.toDate();
    if (dueAt != null && DateTime.now().isAfter(dueAt)) {
      return const TaskStatusResult(status: 'OVERDUE', isApplicable: true);
    }

    return const TaskStatusResult(status: 'PENDING', isApplicable: true);
  }

  Future<List<String>> _tasksDueToday(
    String familyId,
    String childId,
    String timeZone,
  ) async {
    final today = startOfDayInTimeZone(timeZone);
    final todayKey = weekdayKeyForTimeZone(timeZone);
    final assignments = await _family(familyId)
        .collection('taskAssignments')
        .where('childId', isEqualTo: childId)
        .get();

    // Serial awaits here can stall the cloud_firestore web plugin once
    // enough one-shot get() calls queue up — fire them together instead.
    final taskIds = assignments.docs
        .map((assignment) => assignment.data()['taskId'] as String)
        .toList();
    final tasks = await Future.wait(
      taskIds.map(
        (taskId) =>
            _family(familyId).collection('tasks').doc(taskId).get(),
      ),
    );

    final due = <String>[];
    for (var i = 0; i < taskIds.length; i++) {
      final task = tasks[i].data();
      if (task == null) continue;
      final eval = await evaluateTaskForChild(
        familyId: familyId,
        taskId: taskIds[i],
        taskData: task,
        childId: childId,
        today: today,
        todayKey: todayKey,
      );
      if (eval.isApplicable) {
        due.add(taskIds[i]);
      }
    }
    return due;
  }

  /// The status shown for a child on a given day.
  ///
  /// Completions are an append-only log — the rules let a client create one
  /// but never update one — so "undo" writes a new entry and the newest entry
  /// for the day wins.
  Future<String?> latestStatusForDay(
    String familyId,
    String taskId,
    String childId,
    DateTime day,
  ) async {
    final snapshot = await _family(familyId)
        .collection('tasks')
        .doc(taskId)
        .collection('completions')
        .where('childId', isEqualTo: childId)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .get();
    if (snapshot.docs.isEmpty) return null;

    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final at = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch;
        final bt = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch;
        return (bt ?? 0).compareTo(at ?? 0);
      });
    return docs.first.data()['status'] as String?;
  }

  Future<void> _award({
    required String familyId,
    required String childId,
    required String period,
    required String key,
    required int streakValue,
    required int amount,
  }) async {
    try {
      await _family(familyId)
          .collection('streakRewardLogs')
          .doc('${childId}_${period}_$key')
          .set({
            'childId': childId,
            'period': period,
            'streakValue': streakValue,
            'seedsEarned': amount,
            'awardedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException catch (error) {
      // Already awarded: the rules reject the overwrite. Not an error path.
      if (error.code != 'permission-denied') rethrow;
    }
  }

  Future<ChildProgress> childProgressSnapshot(
    String familyId,
    String childId,
    String timeZone,
  ) async {
    final balance = await calculateSeedBalance(familyId, childId);
    final streak = await calculateChildStreak(familyId, childId, timeZone);
    return ChildProgress(seedBalance: balance, streak: streak.count);
  }
}
