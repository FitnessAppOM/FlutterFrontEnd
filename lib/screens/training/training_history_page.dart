import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/Typography/taqa_ui_typography.dart';
import 'package:taqaproject/TaqaUI/components/taqa_log_entry_card.dart';
import 'package:taqaproject/TaqaUI/components/taqa_steps_ui.dart';
import 'package:taqaproject/TaqaUI/styles/taqa_ui_scale.dart';
import 'package:taqaproject/TaqaUI/taqa_ui_colors.dart';

import '../../core/account_storage.dart';
import '../../services/health/workout_health_sync_service.dart';
import '../../services/training/training_reset_coordinator.dart';
import '../../services/training/training_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/training/training_history_health_push_dialog.dart';
import 'training_history_day_detail_page.dart';

class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({
    super.key,
    required this.program,
    this.initialTabIndex = 0,
  });

  final Map<String, dynamic> program;
  final int initialTabIndex;

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  bool _loading = true;
  int _tabIndex = 0;
  bool _pushingHistoryToHealth = false;
  List<_TrainingHistoryEntry> _entries = const [];
  bool _loadingPlanLogs = true;
  List<TrainingPlanChangeEvent> _planLogItems = const [];
  int _unseenPlanLogCount = 0;
  bool _planLogsMarkedSeen = false;

  String _titleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length <= 4 && word == word.toUpperCase()) return word;
          final lower = word.toLowerCase();
          return "${lower[0].toUpperCase()}${lower.substring(1)}";
        })
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _tabIndex = (widget.initialTabIndex >= 0 && widget.initialTabIndex <= 1)
        ? widget.initialTabIndex
        : 0;
    _loadHistory();
    _loadPlanLogs(markSeen: _tabIndex == 1);
    _planLogsMarkedSeen = _tabIndex == 1;
  }

  Future<void> _loadHistory() async {
    try {
      List<_TrainingHistoryEntry> entries = const [];
      final userId = await AccountStorage.getUserId();
      if (userId != null) {
        try {
          final data = await TrainingService.fetchTrainingHistory(
            userId: userId,
          );
          entries = _buildEntriesFromApi(data);
        } catch (_) {
          // Fallback below.
        }
      }
      if (entries.isEmpty) {
        entries = _buildEntriesFromProgram(widget.program);
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      final fallback = _buildEntriesFromProgram(widget.program);
      if (!mounted) return;
      setState(() {
        _entries = fallback;
        _loading = false;
      });
    }
  }

  Future<void> _loadPlanLogs({required bool markSeen}) async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) {
        if (!mounted) return;
        setState(() {
          _loadingPlanLogs = false;
          _planLogItems = const [];
          _unseenPlanLogCount = 0;
        });
        return;
      }
      final payload = await TrainingService.fetchTrainingPlanChanges(
        userId: userId,
        markSeen: markSeen,
      );
      final unseen = payload['unseen_count'] is int
          ? payload['unseen_count'] as int
          : 0;
      final items =
          (payload['items'] as List<TrainingPlanChangeEvent>? ?? const [])
              .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _loadingPlanLogs = false;
        _planLogItems = items;
        _unseenPlanLogCount = markSeen ? 0 : unseen;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPlanLogs = false;
        _planLogItems = const [];
      });
    }
  }

  Future<void> _openPlanLogsTab() async {
    if (_tabIndex == 1) return;
    setState(() {
      _tabIndex = 1;
    });
    if (_planLogsMarkedSeen) return;
    _planLogsMarkedSeen = true;
    await _loadPlanLogs(markSeen: true);
  }

  void _openProgressLogsTab() {
    if (_tabIndex == 0) return;
    setState(() {
      _tabIndex = 0;
    });
  }

  List<_TrainingHistoryEntry> _buildEntriesFromApi(
    List<Map<String, dynamic>> items,
  ) {
    final entries = <_TrainingHistoryEntry>[];
    for (final item in items) {
      final weekStart = _parseDateTime(item['week_start']);
      if (weekStart == null) continue;
      final latestDate = _parseDateTime(item['latest_date']) ?? weekStart;
      final completedRaw = item['completed_exercises'];
      final completedExercises = completedRaw is List
          ? completedRaw
                .map(
                  (e) => e is Map<String, dynamic>
                      ? e
                      : (e is Map ? Map<String, dynamic>.from(e) : null),
                )
                .whereType<Map<String, dynamic>>()
                .toList()
          : const <Map<String, dynamic>>[];
      final totalCountRaw = item['total_count'];
      final completedCountRaw = item['completed_count'];
      final totalCount = totalCountRaw is int
          ? totalCountRaw
          : (totalCountRaw is num
                ? totalCountRaw.round()
                : int.tryParse(totalCountRaw?.toString() ?? '') ??
                      completedExercises.length);
      final completedCount = completedCountRaw is int
          ? completedCountRaw
          : (completedCountRaw is num
                ? completedCountRaw.round()
                : int.tryParse(completedCountRaw?.toString() ?? '') ??
                      completedExercises.length);
      final isCompletedDay =
          item['is_completed_day'] == true ||
          (totalCount > 0 && completedCount >= totalCount);
      final label = (item['label'] ?? item['day_label'] ?? 'Training day')
          .toString();
      final dayKey = (item['day_key'] ?? label).toString();
      final programId = _parseInt(item['program_id']);
      final planDaysPerWeek = _parseInt(
        item['plan_days_per_week'] ?? item['days_per_week'],
      );
      final statusText =
          (item['status_text'] ??
                  (isCompletedDay ? "Completed" : "In progress"))
              .toString();
      final weekLabel = (item['week_label'] ?? '').toString().trim();
      entries.add(
        _TrainingHistoryEntry(
          label: label,
          dayKey: dayKey,
          statusText: statusText,
          isCompletedDay: isCompletedDay,
          completedCount: completedCount,
          totalCount: totalCount,
          weekStart: DateTime(weekStart.year, weekStart.month, weekStart.day),
          weekLabel: weekLabel.isEmpty
              ? _defaultWeekLabel(weekStart)
              : weekLabel,
          completedExercises: completedExercises,
          latestDate: latestDate,
          programId: programId,
          planDaysPerWeek: (planDaysPerWeek != null && planDaysPerWeek > 0)
              ? planDaysPerWeek
              : null,
        ),
      );
    }
    entries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return entries;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is num) {
      final intVal = value.toInt();
      if (intVal > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intVal);
      }
      if (intVal > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime _weekStartMonday(DateTime d) {
    return TrainingResetCoordinator.weekStartMonday(d);
  }

  String _dateToken(DateTime d) {
    return TrainingResetCoordinator.dateToken(d);
  }

  bool _isCompleted(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == "true" || s == "yes" || s == "y" || s == "t" || s == "1") {
      return true;
    }
    final numeric = num.tryParse(s);
    if (numeric != null) return numeric != 0;
    return !(s == "false" || s == "f" || s == "no" || s == "n" || s == "0");
  }

  List<DateTime> _completionDatesFromCompliance(dynamic compliance) {
    if (compliance == null) return const [];
    if (compliance is String) {
      try {
        final decoded = jsonDecode(compliance);
        return _completionDatesFromCompliance(decoded);
      } catch (_) {
        return const [];
      }
    }
    if (compliance is Iterable) {
      final dates = <DateTime>[];
      for (final item in compliance) {
        dates.addAll(_completionDatesFromCompliance(item));
      }
      return dates;
    }
    if (compliance is Map) {
      final possibleFlags = [
        compliance['completed'],
        compliance['is_completed'],
        compliance['performed_sets'],
        compliance['performed_reps'],
        compliance['performed_time_seconds'],
        if (compliance['status'] != null)
          (compliance['status'].toString().toLowerCase().contains("complete") ||
              compliance['status'].toString().toLowerCase().contains("done") ||
              compliance['status'].toString().toLowerCase().contains("finish")),
      ];
      if (!possibleFlags.any(_isCompleted)) return const [];
      final dt = _parseDateTime(
        compliance['logged_at'] ??
            compliance['completed_at'] ??
            compliance['updated_at'] ??
            compliance['performed_at'],
      );
      return dt == null ? const [] : [dt];
    }
    return const [];
  }

  List<DateTime> _completionDatesForExercise(Map<String, dynamic> exercise) {
    final dates = <DateTime>[];
    final seen = <String>{};
    void add(DateTime dt) {
      final key = _dateToken(DateTime(dt.year, dt.month, dt.day));
      if (seen.add(key)) dates.add(dt);
    }

    for (final dt in _completionDatesFromCompliance(
      exercise['program_compliance'],
    )) {
      add(dt);
    }
    for (final dt in _completionDatesFromCompliance(exercise['compliance'])) {
      add(dt);
    }

    if (dates.isNotEmpty) return dates;

    final completionFields = [
      exercise['is_completed'],
      exercise['completed'],
      exercise['program_compliance_completed'],
      exercise['compliance_status'],
      exercise['performed_sets'],
      exercise['performed_reps'],
      exercise['performed_time_seconds'],
      exercise['weight_used'],
    ];
    if (!completionFields.any(_isCompleted)) return const [];

    final dt = _parseDateTime(
      exercise['logged_at'] ??
          exercise['completed_at'] ??
          exercise['updated_at'] ??
          exercise['performed_at'] ??
          exercise['last_performed_at'],
    );
    return dt == null ? const [] : [dt];
  }

  String _defaultWeekLabel(DateTime weekStart) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "Week of ${months[weekStart.month - 1]} ${weekStart.day}, ${weekStart.year}";
  }

  List<_TrainingHistoryPlanGroup> _groupEntriesByPlan(
    List<_TrainingHistoryEntry> entries,
  ) {
    final currentProgramId = _parseInt(
      widget.program['program_id'] ?? widget.program['id'],
    );
    final grouped = <String, _TrainingHistoryPlanGroupBuilder>{};
    for (final entry in entries) {
      final weekToken = _dateToken(entry.weekStart);
      final key = entry.programId != null
          ? "program:${entry.programId}|week:$weekToken"
          : "local:${entry.planDaysPerWeek ?? 0}|week:$weekToken";
      final builder = grouped.putIfAbsent(
        key,
        () => _TrainingHistoryPlanGroupBuilder(programId: entry.programId),
      );
      builder.add(entry);
    }
    final out = grouped.values.map((b) => b.build()).toList()
      ..sort((a, b) {
        final aIsCurrent =
            currentProgramId != null &&
            a.programId != null &&
            a.programId == currentProgramId;
        final bIsCurrent =
            currentProgramId != null &&
            b.programId != null &&
            b.programId == currentProgramId;
        if (aIsCurrent != bIsCurrent) return aIsCurrent ? -1 : 1;
        return b.latestDate.compareTo(a.latestDate);
      });
    return out;
  }

  Widget _buildHistoryEntryCard(
    BuildContext context,
    _TrainingHistoryEntry entry,
  ) {
    final displayStatus = _displayStatusForEntry(entry);
    return TaqaLogEntryCard(
      title: _titleCase(entry.label),
      badgeText: displayStatus.toUpperCase(),
      subtitle: _titleCase(
        "${entry.completedCount} Done, ${entry.weekLabel.replaceFirst('Week of', 'Week Of')}",
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrainingHistoryDayDetailPage(
              dayLabel: entry.label,
              statusText: displayStatus,
              weekLabel: entry.weekLabel,
              completedExercises: entry.completedExercises,
            ),
          ),
        );
      },
    );
  }

  String _displayStatusForEntry(_TrainingHistoryEntry entry) {
    if (entry.isCompletedDay) return "Completed";
    final currentProgramId = _parseInt(
      widget.program['program_id'] ?? widget.program['id'],
    );
    final currentWeekStart = _weekStartMonday(
      TrainingResetCoordinator.currentNowUtc(),
    );
    final entryWeekStart = _weekStartMonday(entry.weekStart);
    final isCurrentPlanThisWeek =
        currentProgramId != null &&
        entry.programId != null &&
        entry.programId == currentProgramId &&
        entryWeekStart == currentWeekStart;
    return isCurrentPlanThisWeek ? "In progress" : "Old plan";
  }

  List<_TrainingHistoryEntry> _buildEntriesFromProgram(
    Map<String, dynamic> program,
  ) {
    final days = program['days'];
    final List dayList = days is List ? days : const [];
    final programId = _parseInt(program['program_id'] ?? program['id']);
    final planDaysPerWeek = dayList.isEmpty ? null : dayList.length;
    final Map<String, _TrainingHistoryEntryBuilder> entryMap = {};

    for (var i = 0; i < dayList.length; i++) {
      final day = dayList[i];
      if (day is! Map) continue;
      final label = (day['day_label'] ?? 'Training day').toString();
      final rawExercises = day['exercises'];
      final exercises = rawExercises is List ? rawExercises : const [];
      final totalCount = exercises.length;
      final dayKey = (day['day_id'] ?? day['id'] ?? day['day_index'] ?? label)
          .toString();

      for (final ex in exercises) {
        final Map<String, dynamic>? exMap = ex is Map<String, dynamic>
            ? ex
            : (ex is Map ? Map<String, dynamic>.from(ex) : null);
        if (exMap == null) continue;
        final dates = _completionDatesForExercise(exMap);
        if (dates.isEmpty) continue;
        for (final dt in dates) {
          final weekStart = _weekStartMonday(dt);
          final key = "${_dateToken(weekStart)}|$dayKey";
          final builder = entryMap.putIfAbsent(
            key,
            () => _TrainingHistoryEntryBuilder(
              label: label,
              dayKey: dayKey,
              weekStart: weekStart,
              totalCount: totalCount,
              latestDate: dt,
              programId: programId,
              planDaysPerWeek: planDaysPerWeek,
            ),
          );
          builder.touch(dt);
          builder.addExercise(exMap);
        }
      }
    }

    final entries = entryMap.values.map((builder) => builder.build()).toList()
      ..sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return entries;
  }

  Map<String, dynamic>? _extractComplianceMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int _positiveInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value > 0 ? value : 0;
    if (value is num) {
      final v = value.toInt();
      return v > 0 ? v : 0;
    }
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null || parsed <= 0) return 0;
    return parsed;
  }

  int _estimateHistoryDurationSeconds(_TrainingHistoryEntry entry) {
    int seconds = 0;
    for (final ex in entry.completedExercises) {
      final compliance =
          _extractComplianceMap(ex['program_compliance']) ??
          _extractComplianceMap(ex['compliance']);
      seconds += _positiveInt(compliance?['performed_time_seconds']);
      seconds += _positiveInt(ex['duration_seconds']);
      seconds += _positiveInt(ex['performed_time_seconds']);
      seconds += _positiveInt(ex['time_seconds']);
      seconds += _positiveInt(ex['elapsed_seconds']);

      if (seconds == 0) {
        final sets = _positiveInt(
          compliance?['performed_sets'] ?? ex['performed_sets'] ?? ex['sets'],
        );
        final reps = _positiveInt(
          compliance?['performed_reps'] ?? ex['performed_reps'] ?? ex['reps'],
        );
        if (sets > 0 && reps > 0) {
          seconds += (sets * reps * 3);
        }
      }
    }

    if (seconds <= 0) {
      final count = entry.completedCount > 0
          ? entry.completedCount
          : entry.completedExercises.length;
      final estimated = count * 300;
      return estimated.clamp(600, 14400);
    }

    final count = entry.completedCount > 0
        ? entry.completedCount
        : entry.completedExercises.length;
    final minimumFromCount = count * 90;
    final normalized = seconds < minimumFromCount ? minimumFromCount : seconds;
    return normalized.clamp(300, 14400);
  }

  DateTime _seedHistorySessionEnd(DateTime day, int index) {
    final base = DateTime(day.year, day.month, day.day, 18, 0);
    return base.add(Duration(minutes: index % 180));
  }

  bool _hasClockTime(DateTime dt) {
    return dt.hour != 0 ||
        dt.minute != 0 ||
        dt.second != 0 ||
        dt.millisecond != 0 ||
        dt.microsecond != 0;
  }

  DateTime? _parseTimestampWithClock(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) {
      if (!_hasClockTime(value)) return null;
      final utc = value.toUtc();
      final isMidnightUtc =
          utc.hour == 0 &&
          utc.minute == 0 &&
          utc.second == 0 &&
          utc.millisecond == 0 &&
          utc.microsecond == 0;
      return isMidnightUtc ? null : value;
    }
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return null;
      final hasClock =
          raw.contains('T') || RegExp(r'\d{1,2}:\d{2}').hasMatch(raw);
      if (!hasClock) return null;
      final dt = DateTime.tryParse(raw);
      if (dt == null) return null;
      final utc = dt.toUtc();
      final isMidnightUtc =
          utc.hour == 0 &&
          utc.minute == 0 &&
          utc.second == 0 &&
          utc.millisecond == 0 &&
          utc.microsecond == 0;
      return isMidnightUtc ? null : dt;
    }
    final dt = _parseDateTime(value);
    if (dt == null || !_hasClockTime(dt)) return null;
    final utc = dt.toUtc();
    final isMidnightUtc =
        utc.hour == 0 &&
        utc.minute == 0 &&
        utc.second == 0 &&
        utc.millisecond == 0 &&
        utc.microsecond == 0;
    return isMidnightUtc ? null : dt;
  }

  DateTime? _extractLatestExerciseTimestamp(Map<String, dynamic> ex) {
    DateTime? best;
    void consider(DateTime? dt) {
      if (dt == null) return;
      if (best == null || dt.isAfter(best!)) {
        best = dt;
      }
    }

    final complianceMaps = <Map<String, dynamic>?>[
      _extractComplianceMap(ex['program_compliance']),
      _extractComplianceMap(ex['compliance']),
    ];
    for (final c in complianceMaps) {
      if (c == null) continue;
      consider(_parseTimestampWithClock(c['logged_at']));
      consider(_parseTimestampWithClock(c['performed_at']));
      consider(_parseTimestampWithClock(c['last_performed_at']));
      consider(_parseTimestampWithClock(c['ended_at']));
      consider(_parseTimestampWithClock(c['end_time']));
      consider(_parseTimestampWithClock(c['finished_at']));
      consider(_parseTimestampWithClock(c['completed_at']));
      consider(_parseTimestampWithClock(c['updated_at']));
    }

    consider(_parseTimestampWithClock(ex['logged_at']));
    consider(_parseTimestampWithClock(ex['performed_at']));
    consider(_parseTimestampWithClock(ex['last_performed_at']));
    consider(_parseTimestampWithClock(ex['ended_at']));
    consider(_parseTimestampWithClock(ex['end_time']));
    consider(_parseTimestampWithClock(ex['finished_at']));
    consider(_parseTimestampWithClock(ex['completed_at']));
    consider(_parseTimestampWithClock(ex['updated_at']));
    return best;
  }

  DateTime _resolveHistorySessionEnd(_TrainingHistoryEntry entry, int index) {
    DateTime? best;
    for (final ex in entry.completedExercises) {
      final ts = _extractLatestExerciseTimestamp(ex);
      if (ts != null && (best == null || ts.isAfter(best))) {
        best = ts;
      }
    }
    if (best != null) return best;
    return _seedHistorySessionEnd(entry.latestDate, index);
  }

  String _historySessionTitle(_TrainingHistoryEntry entry) {
    final label = entry.label.trim();
    if (label.isEmpty) return 'TAQA Strength Workout';
    return '$label Workout';
  }

  String _historySessionDedupeSignature({
    required _TrainingHistoryEntry entry,
    required DateTime start,
    required DateTime end,
  }) {
    final exerciseKeys = <String>[];
    for (final ex in entry.completedExercises) {
      final raw =
          ex['program_exercise_id'] ??
          ex['exercise_id'] ??
          ex['id'] ??
          ex['exercise_name'];
      final key = raw?.toString().trim();
      if (key != null && key.isNotEmpty) {
        exerciseKeys.add(key);
      }
    }
    exerciseKeys.sort();
    return [
      'training_history',
      entry.dayKey.trim().toLowerCase(),
      entry.label.trim().toLowerCase(),
      entry.completedCount.toString(),
      entry.totalCount.toString(),
      start.toUtc().millisecondsSinceEpoch.toString(),
      end.toUtc().millisecondsSinceEpoch.toString(),
      exerciseKeys.join(','),
    ].join('|');
  }

  Future<void> _pushAllTrainingHistoryToAppleHealth() async {
    if (_pushingHistoryToHealth) return;
    if (!Platform.isIOS) {
      AppToast.show(
        context,
        "This history push is for Apple Health on iOS.",
        type: AppToastType.info,
      );
      return;
    }

    final candidates = _entries
        .where((e) => e.completedCount > 0 && e.completedExercises.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      AppToast.show(
        context,
        "No completed training days found to push.",
        type: AppToastType.info,
      );
      return;
    }

    final totalExercises = candidates.fold<int>(
      0,
      (sum, e) => sum + e.completedExercises.length,
    );
    final confirmed = await showTrainingHistoryHealthPushDialog(
      context,
      totalDays: candidates.length,
      totalExercises: totalExercises,
    );
    if (!confirmed) return;

    if (!mounted) return;
    setState(() {
      _pushingHistoryToHealth = true;
    });

    try {
      final sync = WorkoutHealthSyncService();
      int written = 0;
      int skipped = 0;
      int failed = 0;
      for (int i = 0; i < candidates.length; i++) {
        final entry = candidates[i];
        final durationSeconds = _estimateHistoryDurationSeconds(entry);
        final end = _resolveHistorySessionEnd(entry, i);
        final start = end.subtract(Duration(seconds: durationSeconds));
        final result = await sync.writeWorkoutSessionWithStatus(
          start: start,
          end: end,
          title: _historySessionTitle(entry),
          exerciseName: _historySessionTitle(entry),
          isCardio: false,
          workoutBrandName: entry.label,
          isIndoorWorkout: true,
          dedupeSignature: _historySessionDedupeSignature(
            entry: entry,
            start: start,
            end: end,
          ),
        );
        switch (result.status) {
          case WorkoutSessionWriteStatus.written:
            written += 1;
            break;
          case WorkoutSessionWriteStatus.skippedDuplicate:
            skipped += 1;
            break;
          case WorkoutSessionWriteStatus.failed:
            failed += 1;
            break;
        }
      }

      if (!mounted) return;
      final total = candidates.length;
      if (written > 0 && skipped == 0 && failed == 0) {
        AppToast.show(
          context,
          "Finished: pushed $written/$total training days to Apple Health.",
          type: AppToastType.success,
        );
      } else if (written == 0 && skipped > 0 && failed == 0) {
        AppToast.show(
          context,
          "Finished: all $skipped/$total training days were already in Apple Health.",
          type: AppToastType.info,
        );
      } else if (written > 0 && failed == 0) {
        AppToast.show(
          context,
          "Finished: pushed $written new, skipped $skipped already in Apple Health.",
          type: AppToastType.success,
        );
      } else if (written > 0 || skipped > 0) {
        AppToast.show(
          context,
          "Finished with issues: pushed $written, skipped $skipped, failed $failed.",
          type: AppToastType.info,
        );
      } else {
        AppToast.show(
          context,
          "Failed: couldn't push training history to Apple Health.",
          type: AppToastType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        "Failed: couldn't push training history to Apple Health.",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _pushingHistoryToHealth = false;
        });
      }
    }
  }

  String _formatPlanChangeDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(iso.trim());
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _titleForPlanChangeEvent(TrainingPlanChangeEvent event) {
    if (event.coachUserId == null) return 'AI';
    if (event.coachIsAdmin && !event.coachIsAssignedCoach) return 'Admin';
    final firstName = event.coachFirstName?.trim();
    if (firstName != null && firstName.isNotEmpty) return 'Coach $firstName';
    final sourceTo = _labelForPlanSource(event.toPlanSource);
    final sourceFrom = _labelForPlanSource(event.fromPlanSource);
    return sourceTo.isNotEmpty
        ? sourceTo
        : (sourceFrom.isNotEmpty ? sourceFrom : 'Update');
  }

  String _labelForPlanSource(String? source) {
    switch ((source ?? '').trim()) {
      case 'ai_generated':
        return 'AI';
      case 'verified':
        return 'Verified by coach';
      case 'ai_coach':
        return 'AI/Coach';
      case 'coach_edited':
        return 'Coach/edited';
      case 'expert_created':
        return 'Coach-created';
      default:
        return (source ?? '').trim();
    }
  }

  bool _isWholePlanChange(TrainingPlanChangeEvent event) {
    final eventType = event.eventType.trim();
    return eventType == 'plan_created' ||
        eventType == 'template_assigned' ||
        event.sourceProgramId == null;
  }

  List<Widget> _buildPlanChangeDetailWidgets(TrainingPlanChangeEvent event) {
    if (_isWholePlanChange(event)) {
      return [
        Text(
          "Training plan has been changed.",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w600,
            height: 18 / 13,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ];
    }
    if (event.coachUserId == null) {
      return [
        Text(
          "Template changed.",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w600,
            height: 18 / 13,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ];
    }
    if (event.details.isEmpty) return const <Widget>[];

    // 'added'/'removed' show as a +/- pair (an exercise swap shows up as
    // both). 'updated' (sets/reps/rir tweak on the same exercise, no name
    // change) doesn't belong in either bucket.
    final addedNames = <String>[];
    final replacedNames = <String>[];
    for (final change in event.details) {
      final type = (change['type'] ?? '').toString().trim();
      if (type == 'added') {
        final to = change['to'];
        final name = to is Map ? (to['exercise_name'] ?? '').toString().trim() : '';
        if (name.isNotEmpty) addedNames.add(name);
      } else if (type == 'removed') {
        final from = change['from'];
        final name = from is Map
            ? (from['exercise_name'] ?? '').toString().trim()
            : '';
        if (name.isNotEmpty) replacedNames.add(name);
      }
    }

    final widgets = <Widget>[];
    if (addedNames.isNotEmpty) {
      widgets.add(
        Text(
          '+ ${_joinExerciseNames(addedNames)}',
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w600,
            height: 18 / 13,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      );
    }
    if (replacedNames.isNotEmpty) {
      widgets.add(
        Text(
          '- ${_joinExerciseNames(replacedNames)}',
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(13),
            fontWeight: FontWeight.w600,
            height: 18 / 13,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      );
    }
    return widgets;
  }

  String _joinExerciseNames(List<String> names) {
    const maxShown = 4;
    if (names.length <= maxShown) return names.join(', ');
    final shown = names.take(maxShown).join(', ');
    return '$shown +${names.length - maxShown} more';
  }

  Widget _buildProgressLogsContent(List<_TrainingHistoryPlanGroup> grouped) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
      );
    }
    return ListView(
      padding: TaqaUiScale.insetsLTRB(16, 19, 16, 24),
      children: [
        Text(
          "Completed Training Days",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(25),
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        if (_entries.isEmpty) ...[
          SizedBox(height: TaqaUiScale.h(25)),
          Text(
            "No training history yet.",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ] else
          ...grouped.map((group) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: TaqaUiScale.h(25)),
                Text(
                  group.title
                      .replaceAll('days plan', 'Days Plan')
                      .replaceAll('Week of', 'Week Of'),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w700,
                    height: 25 / 15,
                    letterSpacing: 0,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(19)),
                ...group.entries.map(
                  (entry) => _buildHistoryEntryCard(context, entry),
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildPlanLogsContent() {
    if (_loadingPlanLogs) {
      return const Center(
        child: CircularProgressIndicator(
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
      );
    }
    return ListView(
      padding: TaqaUiScale.insetsLTRB(16, 19, 16, 24),
      children: [
        Text(
          "Plan Logs",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(25),
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
        if (_planLogItems.isEmpty) ...[
          SizedBox(height: TaqaUiScale.h(25)),
          Text(
            "No training plan updates yet.",
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 21 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ] else ...[
          SizedBox(height: TaqaUiScale.h(25)),
          ..._planLogItems.map((event) {
            final detailWidgets = _buildPlanChangeDetailWidgets(event);
            final createdAt = _formatPlanChangeDate(event.createdAt);
            final titleLabel = _titleForPlanChangeEvent(event);
            return TaqaLogEntryCard(
              title: _titleCase(titleLabel),
              badgeText: createdAt.toUpperCase(),
              subtitle: event.summary,
              detailWidgets: detailWidgets,
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedEntries = _groupEntriesByPlan(_entries);
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: AppBar(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Training History",
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w700,
            height: 2.5,
            letterSpacing: 0,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TaqaRangeTab(
                    label: "Process Logs",
                    selected: _tabIndex == 0,
                    onTap: _openProgressLogsTab,
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(15)),
                Expanded(
                  child: TaqaRangeTab(
                    label: _unseenPlanLogCount > 0
                        ? "Plan Logs ($_unseenPlanLogCount)"
                        : "Plan Logs",
                    selected: _tabIndex == 1,
                    onTap: _openPlanLogsTab,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tabIndex == 0
                ? _buildProgressLogsContent(groupedEntries)
                : _buildPlanLogsContent(),
          ),
        ],
      ),
    );
  }
}

class _TrainingHistoryEntry {
  const _TrainingHistoryEntry({
    required this.label,
    required this.dayKey,
    required this.statusText,
    required this.isCompletedDay,
    required this.completedCount,
    required this.totalCount,
    required this.weekStart,
    required this.weekLabel,
    required this.completedExercises,
    required this.latestDate,
    this.programId,
    this.planDaysPerWeek,
  });

  final String label;
  final String dayKey;
  final String statusText;
  final bool isCompletedDay;
  final int completedCount;
  final int totalCount;
  final DateTime weekStart;
  final String weekLabel;
  final List<Map<String, dynamic>> completedExercises;
  final DateTime latestDate;
  final int? programId;
  final int? planDaysPerWeek;
}

class _TrainingHistoryEntryBuilder {
  _TrainingHistoryEntryBuilder({
    required this.label,
    required this.dayKey,
    required this.weekStart,
    required this.totalCount,
    required this.latestDate,
    this.programId,
    this.planDaysPerWeek,
  });

  final String label;
  final String dayKey;
  final DateTime weekStart;
  int totalCount;
  DateTime latestDate;
  final int? programId;
  final int? planDaysPerWeek;
  final List<Map<String, dynamic>> _completedExercises = [];
  final Set<String> _exerciseIds = {};

  void touch(DateTime date) {
    if (date.isAfter(latestDate)) {
      latestDate = date;
    }
  }

  void addExercise(Map<String, dynamic> exercise, {String? exerciseKey}) {
    final rawId = exerciseKey?.trim().isNotEmpty == true
        ? exerciseKey
        : (exercise['program_exercise_id'] ??
              exercise['exercise_id'] ??
              exercise['exercise_name']);
    final key = rawId?.toString() ?? "${exercise.hashCode}";
    if (_exerciseIds.add(key)) {
      _completedExercises.add(exercise);
    }
  }

  _TrainingHistoryEntry build() {
    _completedExercises.sort((a, b) {
      int parseOrder(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.round();
        if (v is String) return int.tryParse(v.trim()) ?? 9999;
        return 9999;
      }

      return parseOrder(
        a['order_index'],
      ).compareTo(parseOrder(b['order_index']));
    });
    final completedCount = _completedExercises.length;
    final isCompletedDay = totalCount > 0 && completedCount >= totalCount;
    final statusText = isCompletedDay ? "Completed" : "In progress";
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    final weekLabel =
        "Week of ${months[weekStart.month - 1]} ${weekStart.day}, ${weekStart.year}";
    return _TrainingHistoryEntry(
      label: label,
      dayKey: dayKey,
      statusText: statusText,
      isCompletedDay: isCompletedDay,
      completedCount: completedCount,
      totalCount: totalCount,
      weekStart: weekStart,
      weekLabel: weekLabel,
      completedExercises: List<Map<String, dynamic>>.from(_completedExercises),
      latestDate: latestDate,
      programId: programId,
      planDaysPerWeek: planDaysPerWeek,
    );
  }
}

class _TrainingHistoryPlanGroup {
  const _TrainingHistoryPlanGroup({
    required this.title,
    required this.entries,
    required this.latestDate,
    this.programId,
  });

  final String title;
  final List<_TrainingHistoryEntry> entries;
  final DateTime latestDate;
  final int? programId;
}

class _TrainingHistoryPlanGroupBuilder {
  _TrainingHistoryPlanGroupBuilder({this.programId});

  final int? programId;
  final List<_TrainingHistoryEntry> _entries = [];
  int? _planDaysPerWeek;
  DateTime? _latestDate;
  String? _weekLabel;

  void add(_TrainingHistoryEntry entry) {
    _entries.add(entry);
    if (entry.planDaysPerWeek != null && entry.planDaysPerWeek! > 0) {
      _planDaysPerWeek = entry.planDaysPerWeek;
    }
    if ((_weekLabel ?? '').isEmpty) {
      _weekLabel = entry.weekLabel;
    }
    if (_latestDate == null || entry.latestDate.isAfter(_latestDate!)) {
      _latestDate = entry.latestDate;
    }
  }

  _TrainingHistoryPlanGroup build() {
    final daysPerWeek = _planDaysPerWeek;
    final baseTitle = (daysPerWeek != null && daysPerWeek > 0)
        ? "$daysPerWeek days plan"
        : (programId != null ? "Plan #$programId" : "Training plan");
    final weekLabel = (_weekLabel ?? '').trim();
    final title = weekLabel.isNotEmpty ? "$baseTitle • $weekLabel" : baseTitle;
    _entries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    final latestDate = _latestDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return _TrainingHistoryPlanGroup(
      title: title,
      entries: List<_TrainingHistoryEntry>.from(_entries),
      latestDate: latestDate,
      programId: programId,
    );
  }
}
