import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/account_storage.dart';
import '../../services/training/training_service.dart';
import 'training_history_day_detail_page.dart';

class TrainingHistoryPage extends StatefulWidget {
  const TrainingHistoryPage({super.key, required this.program});

  final Map<String, dynamic> program;

  @override
  State<TrainingHistoryPage> createState() => _TrainingHistoryPageState();
}

class _TrainingHistoryPageState extends State<TrainingHistoryPage> {
  bool _loading = true;
  List<_TrainingHistoryEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
          latestDate: DateTime(
            latestDate.year,
            latestDate.month,
            latestDate.day,
          ),
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
    final day = DateTime(d.year, d.month, d.day);
    final daysSinceMonday = (day.weekday + 6) % 7;
    return day.subtract(Duration(days: daysSinceMonday));
  }

  String _dateToken(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
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
    final grouped = <String, _TrainingHistoryPlanGroupBuilder>{};
    for (final entry in entries) {
      final key = entry.programId != null
          ? "program:${entry.programId}"
          : "local:${entry.planDaysPerWeek ?? 0}";
      final builder = grouped.putIfAbsent(
        key,
        () => _TrainingHistoryPlanGroupBuilder(programId: entry.programId),
      );
      builder.add(entry);
    }
    final out = grouped.values.map((b) => b.build()).toList()
      ..sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return out;
  }

  Widget _buildHistoryEntryCard(
    BuildContext context,
    _TrainingHistoryEntry entry,
  ) {
    final isCompletedDay = entry.isCompletedDay;
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrainingHistoryDayDetailPage(
              dayLabel: entry.label,
              statusText: entry.statusText,
              weekLabel: entry.weekLabel,
              completedExercises: entry.completedExercises,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompletedDay ? null : Colors.white.withOpacity(0.04),
          gradient: isCompletedDay
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E2A1E), Color(0xFF0B1F1A)],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompletedDay
                ? Colors.greenAccent.withOpacity(0.6)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isCompletedDay
                        ? Colors.greenAccent.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompletedDay
                          ? Colors.greenAccent
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    entry.statusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCompletedDay
                          ? Colors.greenAccent
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${entry.completedCount} done • ${entry.weekLabel}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
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
              latestDate: DateTime(dt.year, dt.month, dt.day),
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

  @override
  Widget build(BuildContext context) {
    final groupedEntries = _groupEntriesByPlan(_entries);
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1014),
        elevation: 0,
        title: const Text("Training history"),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                Text(
                  "Completed training days",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                if (_entries.isEmpty)
                  Text(
                    "No training history yet.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  )
                else
                  ...groupedEntries.map((group) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          ...group.entries.map(
                            (entry) => _buildHistoryEntryCard(context, entry),
                          ),
                        ],
                      ),
                    );
                  }),
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
    final day = DateTime(date.year, date.month, date.day);
    if (day.isAfter(latestDate)) {
      latestDate = day;
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
  });

  final String title;
  final List<_TrainingHistoryEntry> entries;
  final DateTime latestDate;
}

class _TrainingHistoryPlanGroupBuilder {
  _TrainingHistoryPlanGroupBuilder({this.programId});

  final int? programId;
  final List<_TrainingHistoryEntry> _entries = [];
  int? _planDaysPerWeek;
  DateTime? _latestDate;

  void add(_TrainingHistoryEntry entry) {
    _entries.add(entry);
    if (entry.planDaysPerWeek != null && entry.planDaysPerWeek! > 0) {
      _planDaysPerWeek = entry.planDaysPerWeek;
    }
    if (_latestDate == null || entry.latestDate.isAfter(_latestDate!)) {
      _latestDate = entry.latestDate;
    }
  }

  _TrainingHistoryPlanGroup build() {
    final daysPerWeek = _planDaysPerWeek;
    final title = (daysPerWeek != null && daysPerWeek > 0)
        ? "$daysPerWeek days plan"
        : (programId != null ? "Plan #$programId" : "Training plan");
    _entries.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    final latestDate = _latestDate ?? DateTime.fromMillisecondsSinceEpoch(0);
    return _TrainingHistoryPlanGroup(
      title: title,
      entries: List<_TrainingHistoryEntry>.from(_entries),
      latestDate: latestDate,
    );
  }
}
