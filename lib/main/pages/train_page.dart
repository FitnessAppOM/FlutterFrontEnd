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
        completed = names.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
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
            t.translate("offline_mode_using_cached_data") ?? "Offline: Using cached data",
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
      final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final thumbW = (74 * dpr).round();
      final thumbH = (66 * dpr).round();
      for (final ex in _trainExercises) {
        if (!mounted) return;
        final url = TrainingService.animationImageUrl(
          ex['animation_url']?.toString(),
          ex['animation_rel_path']?.toString(),
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
      ex['animation_rel_path']?.toString(),
    );
    final ImageProvider? previewProvider =
        gifUrl.isEmpty ? null : TrainingService.gifProvider(
          gifUrl,
          cacheWidth: thumbW,
          cacheHeight: thumbH,
        );
    if (gifUrl.isNotEmpty) {
      // Warm the sheet size without blocking UI.
      TrainingService.warmGif(context, gifUrl, cacheHeight: sheetH).catchError((_) {});
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
        onFinished: _loadProgram,
        previewProvider: previewProvider,
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
      builder: (_) => ReplaceExerciseSheet(
        userId: userId,
        programExercise: ex,
      ),
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
          color: active ? const Color(0xFF2D7CFF) : Colors.white.withOpacity(0.05),
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
      return Center(
        child: Text(t.translate("no_active_training_program")),
      );
    }

    final List days = program!['days'] ?? [];

    if (days.isEmpty) {
      return Center(
        child: Text(t.translate("no_active_training_program")),
      );
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
                          const Icon(Icons.cloud_off, color: Colors.orange, size: 20),
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
                          labels:
                              days.map<String>((d) => d['day_label'].toString()).toList(),
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
                        Text(
                          t.translate("training_exercise_list_title"),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.translate("training_exercise_list_sub"),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                              ),
                        ),
                        const SizedBox(height: 16),
                        if (_trainExercises.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                t.translate("rest_day"),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          )
                        else
                          ..._trainExercises.asMap().entries.map<Widget>((entry) {
                            final ex = entry.value;
                            final rawId = ex['program_exercise_id'] ??
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
