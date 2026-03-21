import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../consents/consent_manager.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/training/exercise_card.dart';
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
    _loadCardioSessionState();
    _loadCardioLibraryFromCache();
    _loadCardioLibrary();
    AccountStorage.trainingChange.addListener(_handleTrainingChange);
    _refreshAlwaysLocationPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCardioSessionState();
  }

  @override
  void didUpdateWidget(covariant CardioTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadCardioSessionState();
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
    setState(() => _showSessionOverlay = true);
    _loadCardioSessionState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCardioSessionState();
      _refreshAlwaysLocationPermission();
    }
  }

  bool _hasCardioSession = false;
  bool _cardioSessionPaused = false;
  String? _sessionExerciseName;
  bool _showSessionOverlay = false;
  List<Map<String, dynamic>> _cardioLibrary = const [];
  bool _loadingCardioLibrary = false;
  bool _hasAlwaysLocationPermission = true;
  bool _locationPermissionLoaded = false;
  bool _requestingAlwaysLocationPermission = false;

  bool _isCardioSession(Map<String, dynamic>? session) {
    if (session == null) return false;
    final distance = session['distanceKm'];
    final pace = session['paceMinKm'];
    return distance is num || pace is num;
  }

  Future<void> _loadCardioSessionState() async {
    final session = await TrainingActivityService.getActiveSession();
    final isCardio = _isCardioSession(session);
    final hasCardioSession = session != null && isCardio;
    final paused = hasCardioSession && session['paused'] == true;
    final rawName = hasCardioSession ? session['name']?.toString() : null;
    if (!mounted) return;
    setState(() {
      _hasCardioSession = hasCardioSession;
      _cardioSessionPaused = paused;
      _sessionExerciseName = rawName;
      _showSessionOverlay = false;
    });
  }

  Future<void> _refreshAlwaysLocationPermission() async {
    final hasAlways = await ConsentManager.hasBackgroundLocationPermission();
    if (!mounted) return;
    setState(() {
      _hasAlwaysLocationPermission = hasAlways;
      _locationPermissionLoaded = true;
    });
  }

  Future<bool> _ensureAlwaysLocationBeforeStart() async {
    final hasAlways = await ConsentManager.hasBackgroundLocationPermission();
    if (!mounted) return hasAlways;
    setState(() {
      _hasAlwaysLocationPermission = hasAlways;
      _locationPermissionLoaded = true;
    });
    if (hasAlways) return true;
    AppToast.show(
      context,
      "Allow 'Always' location to start cardio tracking.",
      type: AppToastType.info,
    );
    return false;
  }

  Future<void> _requestAlwaysLocationPermission() async {
    if (_requestingAlwaysLocationPermission) return;
    setState(() => _requestingAlwaysLocationPermission = true);
    try {
      await ConsentManager.requestBackgroundLocationJIT();
      await _refreshAlwaysLocationPermission();
      if (!mounted) return;
      if (!_hasAlwaysLocationPermission) {
        AppToast.show(
          context,
          "Enable 'Always' location in Settings to use cardio sessions.",
          type: AppToastType.info,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _requestingAlwaysLocationPermission = false);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    await openAppSettings();
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
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final cacheW = (74 * dpr).round();
    final cacheH = (66 * dpr).round();
    for (final ex in items) {
      final url = TrainingService.animationImageUrl(
        ex['animation_url']?.toString(),
        null,
      );
      if (url.isEmpty) continue;
      TrainingService.warmGif(
        context,
        url,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
      ).catchError((_) {});
    }
  }

  List<Map<String, dynamic>> _mergeCardioLibrary(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> remote,
  ) {
    if (remote.isEmpty) return base;
    final byId = <String, Map<String, dynamic>>{};
    for (final r in remote) {
      final key = (r['exercise_id'] ?? r['exercise_name'] ?? '')
          .toString()
          .toLowerCase();
      if (key.isNotEmpty) byId[key] = r;
    }
    return base.map((local) {
      final key = (local['exercise_id'] ?? local['exercise_name'] ?? '')
          .toString()
          .toLowerCase();
      final match = byId[key];
      if (match == null) return local;
      return {
        ...local,
        if (match['animation_url'] != null)
          'animation_url': match['animation_url'],
        'animation_rel_path': null,
      };
    }).toList();
  }

  String _normalizeName(String? name) {
    return (name ?? '').trim().toLowerCase();
  }

  bool _isSessionExercise(Map<String, dynamic> ex) {
    if (!_hasCardioSession) return false;
    final targetName = _normalizeName(_sessionExerciseName);
    if (targetName.isEmpty) return false;
    return _normalizeName(ex['exercise_name']?.toString()) == targetName;
  }

  void _continueCardioSession(List<Map<String, dynamic>> list) {
    final targetName = _normalizeName(_sessionExerciseName);
    if (targetName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't find the cardio session.")),
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
        const SnackBar(
          content: Text("Paused cardio not found. Cancel to start a new one."),
        ),
      );
      return;
    }
    widget.onStart(match);
  }

  Future<void> _cancelPausedSession() async {
    await TrainingActivityService.stopSession();
    if (!mounted) return;
    setState(() {
      _hasCardioSession = false;
      _cardioSessionPaused = false;
      _sessionExerciseName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasProgramCardio = widget.exercises.isNotEmpty;
    final bool locationGateActive =
        _locationPermissionLoaded && !_hasAlwaysLocationPermission;
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
                      MaterialPageRoute(
                        builder: (_) => const CardioHistoryPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text("History"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
            if (locationGateActive)
              _CardioAlwaysLocationGate(
                requesting: _requestingAlwaysLocationPermission,
                onAllow: _requestAlwaysLocationPermission,
                onSettings: _openLocationSettings,
              ),
            IgnorePointer(
              ignoring: locationGateActive,
              child: Opacity(
                opacity: locationGateActive ? 0.35 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasCardioSession)
                      CardioResumeBanner(
                        paused: _cardioSessionPaused,
                        exerciseName: _sessionExerciseName,
                        onContinue: () => _continueCardioSession(list),
                        onCancel: _cancelPausedSession,
                      ),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          "No cardio planned for this day",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: Colors.white),
                        ),
                      )
                    else
                      ...list.map((ex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: ExerciseCard(
                            exercise: ex,
                            disabled: _hasCardioSession,
                            inProgress: _isSessionExercise(ex),
                            onTap: () async {
                              final canStart =
                                  await _ensureAlwaysLocationBeforeStart();
                              if (!canStart || _hasCardioSession) return;
                              widget.onStart(ex);
                            },
                            onReplace: () {
                              if (!hasProgramCardio &&
                                  ex['program_exercise_id'] == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "This cardio item is not in today's plan.",
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (_hasCardioSession) return;
                              widget.onReplace(ex);
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showSessionOverlay)
          const Positioned.fill(child: ColoredBox(color: Colors.black54)),
      ],
    );
  }

  // Map UI moved to CardioMap widget.
}

class _CardioAlwaysLocationGate extends StatelessWidget {
  const _CardioAlwaysLocationGate({
    required this.requesting,
    required this.onAllow,
    required this.onSettings,
  });

  final bool requesting;
  final VoidCallback onAllow;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2338), Color(0xFF101826)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Location access required",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Allow 'Always' location before starting cardio sessions.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _LocationGateActionChip(
            label: requesting ? "Checking..." : "Allow",
            filled: true,
            onTap: requesting ? null : onAllow,
          ),
          const SizedBox(width: 8),
          _LocationGateActionChip(
            label: "Settings",
            filled: false,
            onTap: requesting ? null : onSettings,
          ),
        ],
      ),
    );
  }
}

class _LocationGateActionChip extends StatelessWidget {
  const _LocationGateActionChip({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.black : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
