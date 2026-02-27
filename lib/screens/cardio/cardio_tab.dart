import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../widgets/training/exercise_card.dart';
import '../../widgets/cardio/cardio_map.dart';
import '../../services/training/cardio_session_queue.dart';
import '../../services/training/training_activity_service.dart';
import '../../services/training/training_service.dart';
import '../../services/training/cardio_exercises_storage.dart';
import '../../widgets/cardio/cardio_resume_banner.dart';
import '../../core/account_storage.dart';
import 'cardio_history_page.dart';

class CardioTab extends StatefulWidget {
  const CardioTab({
    super.key,
    required this.exercises,
    required this.onStart,
    required this.onReplace,
  });

  final List<Map<String, dynamic>> exercises;
  final void Function(Map<String, dynamic>) onStart;
  final void Function(Map<String, dynamic>) onReplace;

  @override
  State<CardioTab> createState() => _CardioTabState();
}

class _CardioTabState extends State<CardioTab> with WidgetsBindingObserver {
  static const List<Map<String, dynamic>> _fallbackCardioLibrary = [
    {
      "exercise_id": 4148,
      "exercise_name": "Assault Bike Run",
      "animation_name": "Cardio - Assault Bike Run",
      "animation_rel_path":
          "animations_raw/Cardio - Assault Bike Run/38931301-Assault-Bike-Run_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4149,
      "exercise_name": "Battling Ropes",
      "animation_name": "Cardio - Battling Ropes",
      "animation_rel_path":
          "animations_raw/Cardio - Battling Ropes/33791301-Battling-Ropes-High-Waves_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4150,
      "exercise_name": "Boxing",
      "animation_name": "Cardio - Boxing",
      "animation_rel_path":
          "animations_raw/Cardio - Boxing/45831301-Boxing-Right-Cross-(with-boxing-bag)_Fighting_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4151,
      "exercise_name": "Elliptical Trainer",
      "animation_name": "Cardio - Elliptical Trainer",
      "animation_rel_path":
          "animations_raw/Cardio - Elliptical Trainer/21411301-Walk-Elliptical-Cross-Trainer_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4152,
      "exercise_name": "Jump Rope",
      "animation_name": "Cardio - Jump Rope",
      "animation_rel_path":
          "animations_raw/Cardio - Jump Rope/26121301-Jump-Rope-(male)_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4153,
      "exercise_name": "Rowing Machine",
      "animation_name": "Cardio - Rowing Machine",
      "animation_rel_path":
          "animations_raw/Cardio - Rowing Machine/11611301-Rowing-(with-rowing-machine)_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4154,
      "exercise_name": "Outdoor Run",
      "animation_name": "Cardio - Running",
      "animation_rel_path":
          "animations_raw/Cardio - Running/06851301-Run_Cardio-FIX_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4155,
      "exercise_name": "Treadmill",
      "animation_name": "Cardio - Treadmill",
      "animation_rel_path":
          "animations_raw/Cardio - Treadmill/22591301-Walking-on-Treadmill_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4156,
      "exercise_name": "Skating",
      "animation_name": "Cardio - Skating",
      "animation_rel_path":
          "animations_raw/Cardio - Skating/31091301-Skater-(male)_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4157,
      "exercise_name": "Indoor Cycling",
      "animation_name": "Cardio - Cycling",
      "animation_rel_path":
          "animations_raw/Cardio - Cycling/22791301-Stationary-Bike-Run-(version-4)_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4158,
      "exercise_name": "Outdoor Cycling",
      "animation_name": "Cardio - Cycling",
      "animation_rel_path":
          "animations_raw/Cardio - Cycling/22791301-Stationary-Bike-Run-(version-4)_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
    {
      "exercise_id": 4159,
      "exercise_name": "Walking",
      "animation_name": "Cardio - Walking",
      "animation_rel_path":
          "animations_raw/Cardio - Walking/30041301-Briskly-Walking_Cardio_1080.gif",
      "category": "Cardio",
      "sets": 1,
      "reps": 1,
      "rir": 0,
      "primary_muscles": "Cardio",
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CardioSessionQueue.syncQueue();
    _loadPausedSession();
    _loadCardioLibraryFromCache();
    _loadCardioLibrary();
    AccountStorage.trainingChange.addListener(_handleTrainingChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPausedSession();
  }

  @override
  void didUpdateWidget(covariant CardioTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPausedSession();
    if (widget.exercises != oldWidget.exercises) {
      _precacheGifs(widget.exercises);
    }
  }

  @override
  void dispose() {
    AccountStorage.trainingChange.removeListener(_handleTrainingChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleTrainingChange() {
    if (!mounted) return;
    setState(() => _showPausedOverlay = true);
    _loadPausedSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPausedSession();
    }
  }

  bool _hasPausedSession = false;
  String? _pausedExerciseName;
  bool _showPausedOverlay = false;
  List<Map<String, dynamic>> _cardioLibrary = const [];
  bool _loadingCardioLibrary = false;

  Future<void> _loadPausedSession() async {
    final session = await TrainingActivityService.getActiveSession();
    final paused = session != null && session['paused'] == true;
    if (!mounted) return;
    setState(() {
      _hasPausedSession = paused;
      _pausedExerciseName = paused ? (session?['name'] as String?) : null;
      _showPausedOverlay = false;
    });
  }

  Future<void> _loadCardioLibraryFromCache() async {
    final cached = await CardioExercisesStorage.loadList();
    if (!mounted || cached == null || cached.isEmpty) return;
    setState(() => _cardioLibrary = cached);
  }

  Future<void> _loadCardioLibrary() async {
    if (_loadingCardioLibrary) return;
    setState(() => _loadingCardioLibrary = true);
    try {
      final items = await TrainingService.fetchCardioExercises();
      if (!mounted) return;
      final base = _cardioLibrary.isNotEmpty
          ? _cardioLibrary
          : List<Map<String, dynamic>>.from(_fallbackCardioLibrary);
      final merged = _mergeCardioLibrary(base, items);
      setState(() {
        _cardioLibrary = merged;
        _loadingCardioLibrary = false;
      });
      _precacheGifs(merged);
      CardioExercisesStorage.saveList(merged);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCardioLibrary = false;
      });
    }
  }

  void _precacheGifs(List<Map<String, dynamic>> items) {
    if (!mounted) return;
    for (final ex in items) {
      final url = TrainingService.animationImageUrl(
        ex['animation_url']?.toString(),
        ex['animation_rel_path']?.toString(),
      );
      if (url.isEmpty) continue;
      precacheImage(NetworkImage(url), context).catchError((_) {});
    }
  }

  List<Map<String, dynamic>> _mergeCardioLibrary(
      List<Map<String, dynamic>> base, List<Map<String, dynamic>> remote) {
    if (remote.isEmpty) return base;
    final byId = <String, Map<String, dynamic>>{};
    for (final r in remote) {
      final key = (r['exercise_id'] ?? r['exercise_name'] ?? '').toString().toLowerCase();
      if (key.isNotEmpty) byId[key] = r;
    }
    return base.map((local) {
      final key = (local['exercise_id'] ?? local['exercise_name'] ?? '').toString().toLowerCase();
      final match = byId[key];
      if (match == null) return local;
      return {
        ...local,
        if (match['animation_url'] != null)
          'animation_url': match['animation_url'],
        if (match['animation_rel_path'] != null)
          'animation_rel_path': match['animation_rel_path'],
      };
    }).toList();
  }

  void _continuePausedSession(List<Map<String, dynamic>> list) {
    final targetName = _pausedExerciseName?.trim().toLowerCase();
    if (targetName == null || targetName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find the paused cardio session.")),
      );
      return;
    }
    Map<String, dynamic>? match;
    for (final ex in list) {
      final name = (ex['exercise_name'] ?? '').toString().trim().toLowerCase();
      if (name == targetName) {
        match = ex;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paused cardio not found. Cancel to start a new one.")),
      );
      return;
    }
    widget.onStart(match);
  }

  Future<void> _cancelPausedSession() async {
    await TrainingActivityService.stopSession();
    if (!mounted) return;
    setState(() {
      _hasPausedSession = false;
      _pausedExerciseName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = dotenv.isInitialized ? dotenv.maybeGet('MAPBOX_PUBLIC_KEY') : null;
    final hasToken = token != null && token.trim().isNotEmpty;
    final bool hasProgramCardio = widget.exercises.isNotEmpty;
    final List<Map<String, dynamic>> list = hasProgramCardio
        ? widget.exercises
        : (_cardioLibrary.isNotEmpty
            ? _cardioLibrary
            : List<Map<String, dynamic>>.from(_fallbackCardioLibrary));

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Map hidden for now.
        Row(
          children: [
            Expanded(
              child: Text(
                "Cardio session",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardioHistoryPage()),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text("History"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.08),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Heart-rate focused work",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 16),
        if (_hasPausedSession)
          CardioResumeBanner(
            onContinue: () => _continuePausedSession(list),
            onCancel: _cancelPausedSession,
          ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              "No cardio planned for this day",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          )
        else
          ...list.map((ex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ExerciseCard(
                exercise: ex,
                disabled: _hasPausedSession,
                onTap: () => widget.onStart(ex),
                onReplace: () {
                  if (!hasProgramCardio && ex['program_exercise_id'] == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("This cardio item is not in today's plan."),
                      ),
                    );
                    return;
                  }
                  if (_hasPausedSession) return;
                  widget.onReplace(ex);
                },
              ),
            );
          }).toList(),
          ],
        ),
        if (_showPausedOverlay)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
            ),
          ),
      ],
    );
  }

  // Map UI moved to CardioMap widget.

}
