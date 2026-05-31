import 'package:flutter/material.dart';
import 'package:taqaproject/TaqaUI/components/taqa_action_controls.dart';
import '../../services/training/training_service.dart';
import '../../services/training/exercise_action_queue.dart';
import '../../widgets/app_toast.dart';
import '../../localization/app_localizations.dart';

class ReplaceExerciseSheet extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> programExercise;

  const ReplaceExerciseSheet({
    super.key,
    required this.userId,
    required this.programExercise,
  });

  @override
  State<ReplaceExerciseSheet> createState() => _ReplaceExerciseSheetState();
}

class _ReplaceExerciseSheetState extends State<ReplaceExerciseSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool loadingSuggestions = true;
  bool loadingAll = true;
  bool submitting = false;
  bool isOffline = false;

  List<dynamic> suggestions = [];
  List<dynamic> allExercises = [];
  List<String> muscleTags = [];

  String search = '';
  String? selectedMuscle;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _exerciseTitle(Map<String, dynamic> item) {
    final candidates = [
      item['exercise_name'],
      item['name'],
      item['title'],
      item['display_name'],
    ];
    for (final raw in candidates) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _muscleTagFromAnimationName(String animationName) {
    final raw = animationName.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower == 'nan') return '';
    if (!raw.contains('-')) return '';
    return raw.split('-').first.trim();
  }

  String _muscleTagFromAllExercise(Map<String, dynamic> e) {
    final animName = (e['animation_name'] ?? '').toString();
    return _muscleTagFromAnimationName(animName);
  }

  void _buildTagsFromAll() {
    final set = <String>{};
    for (final ex in allExercises) {
      if (ex is! Map<String, dynamic>) continue;
      final tag = _muscleTagFromAllExercise(ex);
      if (tag.isNotEmpty) set.add(tag);
    }
    muscleTags = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _load() async {
    final programExerciseId = _asInt(
      widget.programExercise['program_exercise_id'],
    );
    if (programExerciseId == null) {
      setState(() {
        loadingSuggestions = false;
        loadingAll = false;
      });
      return;
    }

    bool suggestionsFailed = false;
    bool allFailed = false;

    try {
      final sug = await TrainingService.fetchReplaceSuggestions(
        programExerciseId: programExerciseId,
      );
      if (!mounted) return;
      setState(() {
        suggestions = sug;
        loadingSuggestions = false;
        isOffline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingSuggestions = false;
        suggestionsFailed = true;
      });
    }

    try {
      final all = await TrainingService.fetchAllExercises();
      if (!mounted) return;
      setState(() {
        allExercises = all;
        _buildTagsFromAll();
        loadingAll = false;
        isOffline = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingAll = false;
        allFailed = true;
      });
    }

    // Set offline flag if both failed
    if (suggestionsFailed && allFailed) {
      setState(() => isOffline = true);
    }
  }

  List<dynamic> get filteredAll {
    final s = search.trim().toLowerCase();

    return allExercises.where((item) {
      if (item is! Map<String, dynamic>) return false;

      final name = _exerciseTitle(item).toLowerCase();
      final tag = _muscleTagFromAllExercise(item);

      final okSearch = s.isEmpty || name.contains(s);
      final okMuscle = selectedMuscle == null || selectedMuscle == tag;

      return okSearch && okMuscle;
    }).toList();
  }

  List<dynamic> get filteredSuggestions {
    final s = search.trim().toLowerCase();
    if (s.isEmpty) return suggestions;
    return suggestions.where((item) {
      if (item is! Map<String, dynamic>) return false;
      final name = _exerciseTitle(item).toLowerCase();
      return name.contains(s);
    }).toList();
  }

  Future<void> _doReplace(int newExerciseId, String? newExerciseName) async {
    if (submitting) return;

    final t = AppLocalizations.of(context);
    final currentExerciseName = (widget.programExercise['exercise_name'] ?? '')
        .toString()
        .trim();
    final replacementExerciseName = (newExerciseName ?? '').trim().isEmpty
        ? 'Unnamed exercise'
        : newExerciseName!.trim();
    final currentLabel = currentExerciseName.isEmpty
        ? 'Unnamed exercise'
        : currentExerciseName;

    final confirmed = await showTaqaActionConfirmDialog(
      context: context,
      title: "Replace Exercise",
      message:
          "Are you sure you want to replace this exercise?\n\n\"$currentLabel\" -> \"$replacementExerciseName\"",
      cancelLabel: (t.translate("common_cancel")).toUpperCase(),
      confirmLabel: "REPLACE EXERCISE",
    );

    if (!confirmed) return; // User cancelled

    // Step 2: Ask for reason
    final reason = await _showReasonDialog(newExerciseName ?? '');
    if (reason == null || reason.trim().isEmpty)
      return; // User cancelled or didn't provide reason

    setState(() => submitting = true);

    final programExerciseId =
        _asInt(widget.programExercise['program_exercise_id']) ?? 0;

    try {
      // Try to replace immediately
      await TrainingService.replaceExercise(
        userId: widget.userId,
        programExerciseId: programExerciseId,
        newExerciseId: newExerciseId,
        reason: reason.trim(),
      );

      // If successful, preload feedback questions for new exercise
      if (newExerciseName != null && newExerciseName.isNotEmpty) {
        try {
          await TrainingService.getFeedbackQuestions(newExerciseName);
        } catch (_) {
          // Ignore if questions can't be loaded, will cache later
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Don't queue if server rejected (e.g., already started/completed)
      if (e is TrainingApiException && !e.isRetryable) {
        if (!mounted) return;
        setState(() => submitting = false);
        AppToast.show(context, e.toString(), type: AppToastType.error);
        return;
      }

      // Network failed or retryable error - queue for offline sync
      try {
        await ExerciseActionQueue.queueAction(
          action: ExerciseActionQueue.actionReplace,
          programExerciseId: programExerciseId,
          data: {
            "user_id": widget.userId,
            "new_exercise_id": newExerciseId,
            "new_exercise_name": newExerciseName ?? "",
            "reason": reason.trim(),
          },
        );

        if (!mounted) return;
        setState(() => submitting = false);

        // Show success message with offline notice
        AppToast.show(
          context,
          t.translate("exercise_replace_queued") ??
              "Exercise will be replaced when you're back online.",
          type: AppToastType.info,
        );

        Navigator.pop(context, true); // Close sheet even when offline
      } catch (queueError) {
        // Queue failed too
        if (!mounted) return;
        setState(() => submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<String?> _showReasonDialog(String newExerciseName) async {
    final t = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    String? selectedQuickReason;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            t.translate("replace_reason_title") ??
                "Why are you replacing this exercise?",
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.translate("replace_reason_subtitle") ??
                      "Please tell us why you're replacing this exercise. This helps us improve your program.",
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Quick reason options
                ..._getQuickReasons(t).map(
                  (quickReason) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedQuickReason = quickReason;
                          reasonController.text = quickReason;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedQuickReason == quickReason
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            width: selectedQuickReason == quickReason ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: selectedQuickReason == quickReason
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedQuickReason == quickReason
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 20,
                              color: selectedQuickReason == quickReason
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(quickReason)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText:
                        t.translate("replace_reason_custom") ??
                        "Or enter your own reason",
                    hintText:
                        t.translate("replace_reason_hint") ??
                        "e.g., I don't have the equipment",
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value != selectedQuickReason) {
                        selectedQuickReason = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(t.translate("common_cancel") ?? "Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t.translate("replace_reason_required") ??
                            "Please provide a reason",
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, reason);
              },
              child: Text(t.translate("common_confirm") ?? "Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getQuickReasons(AppLocalizations t) {
    return [
      t.translate("replace_reason_no_equipment") ??
          "I don't have the equipment",
      t.translate("replace_reason_discomfort") ??
          "Exercise causes discomfort/pain",
      t.translate("replace_reason_preference") ??
          "I prefer a different exercise",
      t.translate("replace_reason_difficulty") ??
          "Exercise is too difficult/easy",
      t.translate("replace_reason_other") ?? "Other",
    ];
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tab.index;
    final topInset = MediaQueryData.fromView(View.of(context)).padding.top;

    return SizedBox.expand(
      child: Container(
        color: const Color(0xFF1C1D17),
        padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                ),
                const Expanded(
                  child: Text(
                    "Replace Exercise",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'InterTight',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF45474A),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: TextField(
                style: const TextStyle(
                  fontFamily: 'InterTight',
                  fontSize: 14,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: "Search Exercise",
                  hintStyle: TextStyle(
                    fontFamily: 'InterTight',
                    fontSize: 14,
                    color: Color(0xFFB9B9B9),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFFB9B9B9),
                    size: 20,
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 26),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TaqaSegmentTabButton(
                    label: "RECOMMENDED",
                    active: tabIndex == 0,
                    onTap: () {
                      if (_tab.index != 0) {
                        _tab.animateTo(0);
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TaqaSegmentTabButton(
                    label: "ALL",
                    active: tabIndex == 1,
                    onTap: () {
                      if (_tab.index != 1) {
                        _tab.animateTo(1);
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildSuggestions(), _buildAllList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (loadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isOffline) {
      final t = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Colors.orange.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                t.translate("offline_replace_suggestions") ??
                    "When you're back online, you can get suggestions here.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final items = filteredSuggestions;
    if (items.isEmpty) {
      return const Center(child: Text("No suggestions available"));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = items[i];
        if (s is! Map<String, dynamic>) return const SizedBox.shrink();

        final name = _exerciseTitle(s);
        final animUrl = (s['animation_url'] ?? '').toString().trim();
        final id = _asInt(s['exercise_id']);

        final canTap = id != null && !submitting;
        final replaceId = id ?? 0;

        return _exerciseCard(
          title: name.isEmpty ? "Unnamed exercise" : name,
          animationUrl: animUrl,
          loading: submitting,
          enabled: canTap,
          onTap: canTap ? () => _doReplace(replaceId, name) : null,
        );
      },
    );
  }

  Widget _buildAllList() {
    if (loadingAll) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isOffline) {
      final t = AppLocalizations.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Colors.orange.withOpacity(0.7),
              ),
              const SizedBox(height: 16),
              Text(
                t.translate("offline_replace_all_exercises") ??
                    "When you're back online, you can browse all exercises here.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final items = filteredAll;

    return items.isEmpty
        ? const Center(child: Text("No exercises found"))
        : ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final e = items[i];
              if (e is! Map<String, dynamic>) return const SizedBox.shrink();

              final name = _exerciseTitle(e);
              final animUrl = (e['animation_url'] ?? '').toString().trim();
              final id = _asInt(e['exercise_id']);
              final canTap = id != null && !submitting;
              final replaceId = id ?? 0;

              return _exerciseCard(
                title: name.isEmpty ? "Unnamed exercise" : name,
                animationUrl: animUrl,
                loading: submitting,
                enabled: canTap,
                onTap: canTap ? () => _doReplace(replaceId, name) : null,
              );
            },
          );
  }

  Widget _exerciseCard({
    required String title,
    required String animationUrl,
    required bool loading,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final src = TrainingService.animationImageUrl(animationUrl, null);
    final imageProvider = src.isEmpty
        ? null
        : TrainingService.gifProvider(
            src,
            cacheWidth: (92 * dpr).round(),
            cacheHeight: (92 * dpr).round(),
          );
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Container(
        height: 108,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF45474A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 76,
                height: 76,
                color: Colors.white.withValues(alpha: 0.88),
                child: imageProvider == null
                    ? const SizedBox.shrink()
                    : Image(image: imageProvider, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'InterTight',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
