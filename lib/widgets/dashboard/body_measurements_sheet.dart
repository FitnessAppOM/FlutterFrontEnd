import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../../core/account_storage.dart';
import '../../config/base_url.dart';
import '../../services/auth/profile_service.dart';
import '../../theme/app_theme.dart';
import '../app_toast.dart';

class BodyMeasurementsSheet extends StatefulWidget {
  final double? initialHeightCm;
  final double? initialWeightKg;
  final ValueChanged<BodyMeasurementsResult>? onSaved;

  const BodyMeasurementsSheet({
    super.key,
    this.initialHeightCm,
    this.initialWeightKg,
    this.onSaved,
  });

  @override
  State<BodyMeasurementsSheet> createState() => _BodyMeasurementsSheetState();
}

class _BodyMeasurementsSheetState extends State<BodyMeasurementsSheet> {
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _saving = false;
  List<_BodyLogEntry> _logs = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initialHeightCm != null) {
      _heightCtrl.text = widget.initialHeightCm!.toStringAsFixed(0);
    }
    if (widget.initialWeightKg != null) {
      _weightCtrl.text = widget.initialWeightKg!.toStringAsFixed(0);
    }
    _loadLogs();
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      final url = Uri.parse("${ApiConfig.baseUrl}/questionnaire/$userId/history?limit=60");
      final headers = await AccountStorage.getAuthHeaders();
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return;
      final raw = decoded
          .map((e) => _BodyLogEntry.fromDbJson(e))
          .whereType<_BodyLogEntry>()
          .toList();
      final parsed = <_BodyLogEntry>[];
      _BodyLogEntry? last;
      for (final entry in raw) {
        if (last != null &&
            last.heightCm == entry.heightCm &&
            last.weightKg == entry.weightKg) {
          continue;
        }
        parsed.add(entry);
        last = entry;
      }
      if (!mounted) return;
      setState(() => _logs = parsed);
    } catch (_) {
      // ignore parse errors
    }
  }

  Future<void> _saveLog() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final height = double.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (height == null && weight == null) {
      AppToast.show(context, "Enter height or weight", type: AppToastType.info);
      return;
    }

    setState(() => _saving = true);
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      if (mounted) {
        AppToast.show(context, "Not authenticated", type: AppToastType.error);
        setState(() => _saving = false);
      }
      return;
    }
    final latest = await _fetchLatestQuestionnaire(userId);
    if (latest == null) {
      if (mounted) {
        AppToast.show(context, "Profile data unavailable", type: AppToastType.error);
        setState(() => _saving = false);
      }
      return;
    }
    final payload = _buildProfilePayload(latest, userId);
    final latestHeight = latest["height_cm"] == null
        ? null
        : int.tryParse(latest["height_cm"].toString());
    final latestWeight = latest["weight_kg"] == null
        ? null
        : int.tryParse(latest["weight_kg"].toString());
    final nextHeight = height == null ? null : height.round();
    final nextWeight = weight == null ? null : weight.round();
    final heightChanged = nextHeight != null && nextHeight != latestHeight;
    final weightChanged = nextWeight != null && nextWeight != latestWeight;
    if (!heightChanged && !weightChanged) {
      if (mounted) {
        AppToast.show(context, "No changes to save", type: AppToastType.info);
        setState(() => _saving = false);
      }
      return;
    }
    if (heightChanged) payload["height_cm"] = nextHeight;
    if (weightChanged) payload["weight_kg"] = nextWeight;
    try {
      await ProfileApi.updateProfile(payload);
    } catch (e) {
      if (mounted) {
        AppToast.show(context, "Failed to update profile: $e", type: AppToastType.error);
        setState(() => _saving = false);
      }
      return;
    }

    await _loadLogs();
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call(
      BodyMeasurementsResult(heightCm: height, weightKg: weight),
    );
  }

  Future<Map<String, dynamic>?> _fetchLatestQuestionnaire(int userId) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/questionnaire/$userId");
      final headers = await AccountStorage.getAuthHeaders();
      final res = await http.get(url, headers: headers);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildProfilePayload(Map<String, dynamic> latest, int userId) {
    return <String, dynamic>{
      "user_id": userId,
      "age": latest["age"],
      "sex": latest["sex"],
      "height_cm": latest["height_cm"],
      "weight_kg": latest["weight_kg"],
      "main_goal": latest["main_goal"] ?? latest["fitness_goal"],
      "training_days": latest["training_days"],
      "fitness_experience": latest["fitness_experience"],
      "daily_activity": latest["daily_activity"] ?? latest["occupation"],
      "diet_type": latest["diet_type"],
      "past_injuries": latest["past_injuries"],
      "chronic_conditions": latest["chronic_conditions"],
      "affiliation_id": latest["affiliation_id"],
      "affiliation_other_text": latest["affiliation_other_text"],
      "is_university_student": latest["is_university_student"],
      "university_id": latest["university_id"],
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInset),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1D1F27), Color(0xFF13151C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.dividerDark),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Row(
                    children: [
                      Text("Body measurements",
                          style: AppTextStyles.subtitle.copyWith(color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MeasurementField(
                    label: "Height (cm)",
                    controller: _heightCtrl,
                    icon: Icons.height,
                  ),
                  const SizedBox(height: 12),
                  _MeasurementField(
                    label: "Weight (kg)",
                    controller: _weightCtrl,
                    icon: Icons.monitor_weight,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(_saving ? "Saving..." : "Save"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "History",
                      style: AppTextStyles.small.copyWith(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "No measurements yet.",
                        style: AppTextStyles.small.copyWith(color: AppColors.textDim),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _logs[index];
                        return _HistoryTile(entry: entry);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MeasurementField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _MeasurementField({
    required this.label,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _BodyLogEntry entry;

  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, y • h:mm a').format(entry.timestamp);
    final heightLabel =
        entry.heightCm == null ? "—" : "${entry.heightCm!.toStringAsFixed(0)} cm";
    final weightLabel =
        entry.weightKg == null ? "—" : "${entry.weightKg!.toStringAsFixed(0)} kg";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$heightLabel • $weightLabel",
                  style: AppTextStyles.subtitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: AppTextStyles.small.copyWith(color: AppColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BodyMeasurementsResult {
  final double? heightCm;
  final double? weightKg;

  BodyMeasurementsResult({this.heightCm, this.weightKg});
}

class _BodyLogEntry {
  final DateTime timestamp;
  final double? heightCm;
  final double? weightKg;

  _BodyLogEntry({
    required this.timestamp,
    this.heightCm,
    this.weightKg,
  });

  static _BodyLogEntry? fromDbJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final tsRaw = json["created_at"]?.toString();
    final ts = tsRaw == null ? null : DateTime.tryParse(tsRaw);
    if (ts == null) return null;
    final height = json["height_cm"];
    final weight = json["weight_kg"];
    return _BodyLogEntry(
      timestamp: ts,
      heightCm: height == null ? null : double.tryParse(height.toString()),
      weightKg: weight == null ? null : double.tryParse(weight.toString()),
    );
  }
}
