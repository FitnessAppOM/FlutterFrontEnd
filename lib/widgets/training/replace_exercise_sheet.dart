import 'package:flutter/material.dart';
import '../../services/training_service.dart';

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

    try {
      final sug = await TrainingService.fetchReplaceSuggestions(
        programExerciseId: programExerciseId,
      );
      if (!mounted) return;
      setState(() {
        suggestions = sug;
        loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingSuggestions = false);
    }

    try {
      final all = await TrainingService.fetchAllExercises();
      if (!mounted) return;
      setState(() {
        allExercises = all;
        _buildTagsFromAll();
        loadingAll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingAll = false);
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

  Future<void> _doReplace(int newExerciseId) async {
    if (submitting) return;
    setState(() => submitting = true);

    try {
      await TrainingService.replaceExercise(
        userId: widget.userId,
        programExerciseId: _asInt(widget.programExercise['program_exercise_id']) ?? 0,
        newExerciseId: newExerciseId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
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
          onTap: canTap ? () => _doReplace(id!) : null,
        );
      },
    );
  }

  Widget _buildAllList() {
    if (loadingAll) {
      return const Center(child: CircularProgressIndicator());
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
                onTap: canTap ? () => _doReplace(id!) : null,
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
