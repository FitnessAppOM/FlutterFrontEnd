import 'package:flutter/material.dart';
import '../../services/training_service.dart';
import '../../services/exercise_action_queue.dart';
import '../../widgets/app_toast.dart';
import '../../localization/app_localizations.dart';
import '../../theme/app_theme.dart';

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
    final programExerciseId = _asInt(widget.programExercise['program_exercise_id']);
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

      final name = (item['exercise_name'] ?? '').toString().trim().toLowerCase();
      final tag = _muscleTagFromAllExercise(item);

      final okSearch = s.isEmpty || name.contains(s);
      final okMuscle = selectedMuscle == null || selectedMuscle == tag;

      return okSearch && okMuscle;
    }).toList();
  }

  Future<void> _doReplace(int newExerciseId, String? newExerciseName) async {
    if (submitting) return;

    final t = AppLocalizations.of(context);
    final currentExerciseName = (widget.programExercise['exercise_name'] ?? '').toString();
    final replacementExerciseName = newExerciseName ?? 'this exercise';

    // Step 1: Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate("confirm_replace") ?? "Confirm Replacement"),
        content: Text(
          "Are you sure you want to replace \"$currentExerciseName\" with \"$replacementExerciseName\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.translate("common_cancel") ?? "Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.translate("common_confirm") ?? "Confirm"),
          ),
        ],
      ),
    );

    if (confirmed != true) return; // User cancelled

    // Step 2: Ask for reason
    final reason = await _showReasonDialog(newExerciseName ?? '');
    if (reason == null || reason.trim().isEmpty) return; // User cancelled or didn't provide reason

    setState(() => submitting = true);

    final programExerciseId = _asInt(widget.programExercise['program_exercise_id']) ?? 0;

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
      // Network failed - queue for offline sync
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
          t.translate("exercise_replace_queued") ?? "Exercise will be replaced when you're back online.",
          type: AppToastType.info,
        );
        
        Navigator.pop(context, true); // Close sheet even when offline
      } catch (queueError) {
        // Queue failed too
        if (!mounted) return;
        setState(() => submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
          title: Text(t.translate("replace_reason_title") ?? "Why are you replacing this exercise?"),
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
                ..._getQuickReasons(t).map((quickReason) => Padding(
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
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
                )),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: t.translate("replace_reason_custom") ?? "Or enter your own reason",
                    hintText: t.translate("replace_reason_hint") ?? "e.g., I don't have the equipment",
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
                      content: Text(t.translate("replace_reason_required") ?? "Please provide a reason"),
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
      t.translate("replace_reason_no_equipment") ?? "I don't have the equipment",
      t.translate("replace_reason_discomfort") ?? "Exercise causes discomfort/pain",
      t.translate("replace_reason_preference") ?? "I prefer a different exercise",
      t.translate("replace_reason_difficulty") ?? "Exercise is too difficult/easy",
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
    final exName = (widget.programExercise['exercise_name'] ?? '').toString();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Replace: $exName",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: "Suggested"),
                Tab(text: "All"),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildSuggestions(),
                  _buildAllList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbRelPath(String? animRelPath) {
    final p = (animRelPath ?? '').trim();
    if (p.isEmpty) return const Icon(Icons.fitness_center);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        "${TrainingService.baseUrl}/static/$p",
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center),
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
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (suggestions.isEmpty) {
      return const Center(child: Text("No suggestions available"));
    }

    return ListView.separated(
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = suggestions[i];
        if (s is! Map<String, dynamic>) return const SizedBox.shrink();

        final name = (s['exercise_name'] ?? '').toString().trim();
        final animRel = (s['animation_rel_path'] ?? '').toString().trim();
        final id = _asInt(s['exercise_id']);

        final canTap = id != null && !submitting;

        return ListTile(
          leading: _thumbRelPath(animRel),
          title: Text(name.isEmpty ? "Unnamed exercise" : name),
          trailing: submitting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.chevron_right),
          enabled: canTap,
          onTap: canTap ? () => _doReplace(id!, name) : null,
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
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = filteredAll;

    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: "Search exercise...",
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip("All", selectedMuscle == null, () {
                setState(() => selectedMuscle = null);
              }),
              ...muscleTags.map((m) => _chip(m, selectedMuscle == m, () {
                setState(() => selectedMuscle = m);
              })),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text("No exercises found"))
              : ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = items[i];
              if (e is! Map<String, dynamic>) return const SizedBox.shrink();

              final name = (e['exercise_name'] ?? '').toString().trim();
              final animName = (e['animation_name'] ?? '').toString().trim();
              final tag = _muscleTagFromAnimationName(animName);

              final id = _asInt(e['exercise_id']);
              final canTap = id != null && !submitting;

              return ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(name.isEmpty ? "Unnamed exercise" : name),
                subtitle: tag.isEmpty ? null : Text(tag),
                trailing: submitting
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.chevron_right),
                enabled: canTap,
                onTap: canTap ? () => _doReplace(id!, name) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: active,
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
