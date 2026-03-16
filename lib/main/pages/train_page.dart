import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/training/day_selector.dart';
import '../../widgets/training/exercise_card.dart';
import '../../widgets/training/exercise_session_sheet.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../services/training/training_service.dart';
import '../../widgets/training/replace_exercise_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../screens/cardio/cardio_tab.dart';
import '../../consents/consent_manager.dart';
import '../../screens/training/training_history_page.dart';
import '../../widgets/training/training_day_complete_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainPage extends StatefulWidget {
  const TrainPage({super.key});

  @override
  State<TrainPage> createState() => _TrainPageState();
}

class _TrainPageState extends State<TrainPage> {
  Map<String, dynamic>? program;
  int selectedDay = 0;
  bool loading = true;
  bool isOffline = false;
  Set<String> completedExerciseNames = {};
  int _tabIndex = 0; // 0 = Train, 1 = Cardio
  bool _cardioBuilt = false;
  List<Map<String, dynamic>> _trainExercises = const [];
  List<Map<String, dynamic>> _cardioExercises = const [];
  final Set<String> _preloadedThumbs = <String>{};

  int? _userId;
  int? _pendingCompletionDayIndex;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await AccountStorage.getUserId();
    await _loadProgram();
  }

  Future<void> _loadProgram() async {
    bool showedCache = false;
    try {
      final userId = _userId ?? await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      // Show cached program immediately if available (no blank UI).
      if (program == null) {
        try {
          final cached = await TrainingService.fetchActiveProgramFromCache();
          if (cached != null && mounted) {
            setState(() {
              program = cached;
              loading = false;
              isOffline = false;
              _rebuildExerciseLists();
            });
            showedCache = true;
            _preloadExerciseGifsForCurrentDay();
          }
        } catch (_) {
          // Ignore cache load errors.
        }
      }

      // Try to sync queued actions first (if online)
      try {
        await ExerciseActionQueue.syncQueue();
      } catch (_) {
        // Ignore sync errors, continue loading program
      }

      // Try to fetch from server first
      final data = await TrainingService.fetchActiveProgram(userId);
      Set<String> completed = {};
      try {
        final names = await TrainingService.fetchCompletedExerciseNames(userId);
        completed = names
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      } catch (_) {
        // Ignore completed names fetch errors
      }
      if (!mounted) return;
      setState(() {
        program = data;
        loading = false;
        isOffline = false;
        completedExerciseNames = completed;
        _rebuildExerciseLists();
      });
      _preloadExerciseGifsForCurrentDay();
      await _maybeShowDayCompletedPopup();
      return;
    } catch (_) {
      if (!mounted) return;
      if (program != null || showedCache) {
        setState(() {
          loading = false;
          isOffline = true;
        });
        if (showedCache) {
          final t = AppLocalizations.of(context);
          AppToast.show(
            context,
            t.translate("offline_mode_using_cached_data") ??
                "Offline: Using cached data",
            type: AppToastType.info,
          );
        }
      } else {
        setState(() {
          loading = false;
          program = null;
          isOffline = false;
          _rebuildExerciseLists();
        });
      }
    }
  }

  void _rebuildExerciseLists() {
    final data = program;
    if (data == null) {
      _trainExercises = const [];
      _cardioExercises = const [];
      return;
    }
    final days = data['days'];
    if (days is! List || days.isEmpty) {
      _trainExercises = const [];
      _cardioExercises = const [];
      return;
    }
    if (selectedDay >= days.length) {
      selectedDay = 0;
    }
    final currentDay = days[selectedDay];
    final exercises = currentDay is Map ? currentDay['exercises'] : null;
    final List<Map<String, dynamic>> train = [];
    final List<Map<String, dynamic>> cardio = [];
    if (exercises is List) {
      for (final ex in exercises) {
        if (ex is Map<String, dynamic>) {
          if (_isCardioExercise(ex)) {
            cardio.add(ex);
          } else {
            train.add(ex);
          }
        }
      }
    }
    _trainExercises = train;
    _cardioExercises = cardio;
  }

  Future<void> _preloadExerciseGifsForCurrentDay() async {
    if (!mounted) return;
    try {
      final dpr = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .devicePixelRatio;
      final thumbW = (74 * dpr).round();
      final thumbH = (66 * dpr).round();
      for (final ex in _trainExercises) {
        if (!mounted) return;
        final url = TrainingService.animationImageUrl(
          ex['animation_url']?.toString(),
          null,
        );
        if (url.isEmpty) continue;
        final key = "$url|$thumbW|$thumbH";
        if (_preloadedThumbs.contains(key)) continue;
        _preloadedThumbs.add(key);
        try {
          await TrainingService.warmGif(
            context,
            url,
            cacheWidth: thumbW,
            cacheHeight: thumbH,
          );
        } catch (_) {
          // Ignore individual preload failures.
        }
      }
    } catch (_) {
      // Ignore preload failures.
    }
  }

  void _startExerciseFlow(Map<String, dynamic> ex) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thumbW = (74 * dpr).round();
    final thumbH = (66 * dpr).round();
    final sheetH = (160 * dpr).round();
    final gifUrl = TrainingService.animationImageUrl(
      ex['animation_url']?.toString(),
      null,
    );
    final ImageProvider? previewProvider = gifUrl.isEmpty
        ? null
        : TrainingService.gifProvider(
            gifUrl,
            cacheWidth: thumbW,
            cacheHeight: thumbH,
          );
    if (gifUrl.isNotEmpty) {
      // Warm the sheet size without blocking UI.
      TrainingService.warmGif(
        context,
        gifUrl,
        cacheHeight: sheetH,
      ).catchError((_) {});
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExerciseSessionSheet(
        exercise: ex,
        completedExerciseNames: completedExerciseNames,
        onFinished: () {
          _pendingCompletionDayIndex = selectedDay;
          unawaited(_loadProgram());
        },
        previewProvider: previewProvider,
        showSessionOnOpen: true,
      ),
    );
  }

  Future<void> _openCardioTab() async {
    final ok = await ConsentManager.requestBackgroundLocationJIT();
    if (!ok && mounted) {
      AppToast.show(
        context,
        "Location permission is required to show your position on the cardio map.",
        type: AppToastType.info,
      );
    }
    if (!mounted) return;
    setState(() {
      _tabIndex = 1;
      _cardioBuilt = true;
    });
  }

  Future<void> _openReplaceSheet(Map<String, dynamic> ex) async {
    final userId = _userId;
    if (userId == null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReplaceExerciseSheet(userId: userId, programExercise: ex),
    );

    if (changed == true) {
      // Try to sync queued actions (in case replace was queued)
      try {
        await ExerciseActionQueue.syncQueue();
      } catch (_) {
        // Ignore sync errors
      }
      await _loadProgram();
    }
  }

  bool _isCardioExercise(Map<String, dynamic> ex) {
    String? _str(dynamic v) => v == null ? null : v.toString().toLowerCase();

    final animationName = _str(ex['animation_name']) ?? '';
    // Trust explicit cardio tag in animation_name (e.g., "Cardio - ...")
    return animationName.startsWith('cardio -');
  }

  DateTime _weekStartMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final daysSinceMonday = (day.weekday + 6) % 7;
    return day.subtract(Duration(days: daysSinceMonday));
  }

  DateTime _weekEndSunday(DateTime d) {
    final start = _weekStartMonday(d);
    return start.add(const Duration(days: 6));
  }

  String _dateToken(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
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

  bool _flagTrue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final s = value.toString().trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s == "true" || s == "yes" || s == "y" || s == "t" || s == "1")
      return true;
    final numeric = num.tryParse(s);
    if (numeric != null) return numeric != 0;
    return !(s == "false" || s == "f" || s == "no" || s == "n" || s == "0");
  }

  bool _isInWeek(DateTime date, DateTime weekStart, DateTime weekEnd) {
    return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
  }

  bool _complianceCompletedForWeek(
    dynamic compliance,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (compliance == null) return false;
    if (compliance is Map) {
      final loggedAt = _parseDateTime(
        compliance['logged_at'] ??
            compliance['completed_at'] ??
            compliance['updated_at'] ??
            compliance['performed_at'],
      );
      if (loggedAt == null) return false;
      if (!_isInWeek(loggedAt, weekStart, weekEnd)) return false;
      final flags = [
        compliance['completed'],
        compliance['is_completed'],
        compliance['performed_sets'],
        compliance['performed_reps'],
        compliance['performed_time_seconds'],
        if (compliance['status'] != null)
          compliance['status'].toString().toLowerCase().contains("complete") ||
              compliance['status'].toString().toLowerCase().contains("done") ||
              compliance['status'].toString().toLowerCase().contains("finish"),
      ];
      return flags.any(_flagTrue);
    }
    if (compliance is Iterable) {
      return compliance.any(
        (item) => _complianceCompletedForWeek(item, weekStart, weekEnd),
      );
    }
    if (compliance is String) {
      try {
        final decoded = jsonDecode(compliance);
        return _complianceCompletedForWeek(decoded, weekStart, weekEnd);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  DateTime? _exerciseCompletionDate(Map<String, dynamic> ex) {
    final candidates = [
      ex['logged_at'],
      ex['completed_at'],
      ex['updated_at'],
      ex['performed_at'],
      ex['last_performed_at'],
    ];
    for (final c in candidates) {
      final dt = _parseDateTime(c);
      if (dt != null) return dt;
    }
    return null;
  }

  bool _isExerciseCompletedForWeek(
    Map<String, dynamic> ex,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    if (_complianceCompletedForWeek(
          ex['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(ex['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final completionDate = _exerciseCompletionDate(ex);
    if (completionDate == null ||
        !_isInWeek(completionDate, weekStart, weekEnd)) {
      return false;
    }

    final flags = [
      ex['is_completed'],
      ex['completed'],
      ex['program_compliance_completed'],
      ex['performed_sets'],
      ex['performed_reps'],
      ex['performed_time_seconds'],
      ex['weight_used'],
    ];
    return flags.any(_flagTrue);
  }

  bool _isDayCompletedForWeek(
    Map<String, dynamic> day,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final flags = [
      day['is_completed'],
      day['completed'],
      day['program_compliance_completed'],
    ];
    if (flags.any(_flagTrue)) return true;
    if (_complianceCompletedForWeek(
          day['program_compliance'],
          weekStart,
          weekEnd,
        ) ||
        _complianceCompletedForWeek(day['compliance'], weekStart, weekEnd)) {
      return true;
    }

    final exercises = day['exercises'];
    if (exercises is! List || exercises.isEmpty) return false;
    for (final ex in exercises) {
      if (ex is Map<String, dynamic>) {
        if (!_isExerciseCompletedForWeek(ex, weekStart, weekEnd)) return false;
      } else if (ex is Map) {
        if (!_isExerciseCompletedForWeek(
          Map<String, dynamic>.from(ex),
          weekStart,
          weekEnd,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  String _dayCompletionKey(
    Map<String, dynamic> day,
    int index,
    DateTime weekStart,
  ) {
    final rawId =
        day['day_id'] ??
        day['id'] ??
        day['day_label'] ??
        day['day_name'] ??
        "day_${index + 1}";
    final safeId = rawId.toString().replaceAll(RegExp(r'\s+'), '_');
    return "${_dateToken(weekStart)}_$safeId";
  }

  Future<void> _maybeShowDayCompletedPopup() async {
    final index = _pendingCompletionDayIndex;
    _pendingCompletionDayIndex = null;
    final data = program;
    if (index == null || data == null) return;
    final days = data['days'];
    if (days is! List || index < 0 || index >= days.length) return;
    final day = days[index];
    if (day is! Map<String, dynamic>) return;

    final now = DateTime.now();
    final weekStart = _weekStartMonday(now);
    final weekEnd = _weekEndSunday(now);
    if (!_isDayCompletedForWeek(day, weekStart, weekEnd)) return;

    final userId = _userId ?? await AccountStorage.getUserId();
    if (userId == null) return;
    final sp = await SharedPreferences.getInstance();
    final key =
        "train_day_completed_popup_u${userId}_${_dayCompletionKey(day, index, weekStart)}";
    if (sp.getBool(key) == true) return;
    await sp.setBool(key, true);

    if (!mounted) return;
    final label = (day['day_label'] ?? 'Training day').toString();
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingDayCompleteSheet(dayLabel: label),
    );
  }

  Widget _tabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF2D7CFF)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? const Color(0xFF2D7CFF) : Colors.white24,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (loading && program == null) {
      return _buildLoadingSkeleton(context);
    }

    if (program == null) {
      return Center(child: Text(t.translate("no_active_training_program")));
    }

    final List days = program!['days'] ?? [];

    if (days.isEmpty) {
      return Center(child: Text(t.translate("no_active_training_program")));
    }

    if (selectedDay >= days.length) {
      selectedDay = 0;
    }

    final currentDay = days[selectedDay];

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOffline)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.translate("offline_mode") ?? "Offline Mode",
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SectionHeader(title: t.translate("training")),
                  const SizedBox(height: 12),
                  if (_tabIndex == 0) ...[
                    Text(
                      currentDay['day_label'] ?? "",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      _tabButton(
                        label: "Train",
                        active: _tabIndex == 0,
                        onTap: () => setState(() => _tabIndex = 0),
                      ),
                      const SizedBox(width: 10),
                      _tabButton(
                        label: "Cardio",
                        active: _tabIndex == 1,
                        onTap: _openCardioTab,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: Colors.black87,
                    onRefresh: _loadProgram,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        DaySelector(
                          labels: days
                              .map<String>((d) => d['day_label'].toString())
                              .toList(),
                          selectedIndex: selectedDay,
                          onSelect: (i) {
                            setState(() {
                              selectedDay = i;
                              _rebuildExerciseLists();
                            });
                            _preloadExerciseGifsForCurrentDay();
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.translate("training_exercise_list_title"),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final currentProgram = program;
                                if (currentProgram == null) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TrainingHistoryPage(
                                      program: currentProgram,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text("History"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.translate("training_exercise_list_sub"),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        if (_trainExercises.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                t.translate("rest_day"),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          )
                        else
                          ..._trainExercises.asMap().entries.map<Widget>((
                            entry,
                          ) {
                            final ex = entry.value;
                            final rawId =
                                ex['program_exercise_id'] ??
                                ex['exercise_id'] ??
                                ex['exercise_name'] ??
                                entry.key;
                            final exKey = ValueKey("train_ex_$rawId");
                            return Padding(
                              key: exKey,
                              padding: const EdgeInsets.only(bottom: 14),
                              child: ExerciseCard(
                                exercise: ex,
                                onTap: () => _startExerciseFlow(ex),
                                onReplace: () => _openReplaceSheet(ex),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: Colors.black87,
                    onRefresh: _loadProgram,
                    child: _cardioBuilt
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              const SizedBox(height: 8),
                              CardioTab(
                                exercises: _cardioExercises,
                                onStart: _startExerciseFlow,
                                onReplace: _openReplaceSheet,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final t = AppLocalizations.of(context);

    Widget skeletonLine({double width = 120, double height = 12}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    Widget skeletonCard() {
      return Container(
        height: 86,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
      );
    }

    Widget skeletonPill({double width = 110}) {
      return Container(
        height: 36,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: t.translate("training")),
                  const SizedBox(height: 12),
                  skeletonLine(width: 140, height: 16),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      skeletonPill(width: 120),
                      const SizedBox(width: 10),
                      skeletonPill(width: 120),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 24),
                  skeletonLine(width: 180, height: 14),
                  const SizedBox(height: 6),
                  skeletonLine(width: 240, height: 12),
                  const SizedBox(height: 16),
                  for (int i = 0; i < 4; i++) skeletonCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
