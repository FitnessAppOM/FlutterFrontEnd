import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/account_storage.dart';
import '../../services/health/water_service.dart';
import '../../services/metrics/daily_metrics_api.dart';
import '../../theme/app_theme.dart';
import '../app_toast.dart';

class WaterIntakeSheet extends StatefulWidget {
  final double? initialGoal;
  final double? initialIntake;
  final VoidCallback? onSaved;

  const WaterIntakeSheet({
    super.key,
    this.initialGoal,
    this.initialIntake,
    this.onSaved,
  });

  @override
  State<WaterIntakeSheet> createState() => _WaterIntakeSheetState();
}

class _WaterIntakeSheetState extends State<WaterIntakeSheet> {
  final _goalCtrl = TextEditingController();
  final _intakeCtrl = TextEditingController();
  bool _saving = false;
  List<_WaterLogEntry> _logs = const [];

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = (widget.initialGoal ?? 2.5).toStringAsFixed(1);
    _intakeCtrl.text = (widget.initialIntake ?? 0).toStringAsFixed(1);
    _loadLogs();
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _intakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 29));
      final normalizedEnd = DateTime(end.year, end.month, end.day);
      final normalizedStart = DateTime(start.year, start.month, start.day);
      final todayKey = DateTime(end.year, end.month, end.day);

      final fetched = await DailyMetricsApi.fetchRange(
        userId: userId,
        start: normalizedStart,
        end: normalizedEnd,
      );

      // Override today's water with locally saved value for the current user.
      final localToday = await WaterService().getIntakeForDay(todayKey);

      final entries = <_WaterLogEntry>[];
      for (int i = 0; i < 30; i++) {
        final d = normalizedStart.add(Duration(days: i));
        final entry = fetched[d];
        double liters = entry?.waterLiters ?? 0;
        if (d == todayKey && localToday >= 0) {
          liters = localToday;
        }
        if (liters > 0) {
          entries.add(_WaterLogEntry(date: d, liters: liters));
        }
      }
      if (!mounted) return;
      setState(() => _logs = entries.reversed.toList());
    } catch (_) {
      // ignore
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final goal = double.tryParse(_goalCtrl.text.trim());
    final intake = double.tryParse(_intakeCtrl.text.trim());
    if (goal == null && intake == null) {
      AppToast.show(context, "Enter goal or intake", type: AppToastType.info);
      return;
    }
    final userId = await AccountStorage.getUserId();
    if (userId == null) {
      AppToast.show(context, "Not authenticated", type: AppToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      if (goal != null && goal > 0) {
        await WaterService().setGoal(goal);
      }
      if (intake != null && intake >= 0) {
        final current = await WaterService().getTodayIntake();
        if (current == intake) {
          if (mounted) {
            AppToast.show(context, "No change to save", type: AppToastType.info);
            setState(() => _saving = false);
          }
          return;
        }
        await WaterService().setTodayIntake(intake);
      }
    } catch (e) {
      AppToast.show(context, "Failed to save: $e", type: AppToastType.error);
      if (mounted) setState(() => _saving = false);
      return;
    }
    await _loadLogs();
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved?.call();
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
                      Text("Water intake",
                          style: AppTextStyles.subtitle.copyWith(color: Colors.white)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FieldRow(
                    label: "Goal (L)",
                    controller: _goalCtrl,
                    icon: Icons.flag,
                  ),
                  const SizedBox(height: 12),
                  _FieldRow(
                    label: "Today intake (L)",
                    controller: _intakeCtrl,
                    icon: Icons.water_drop,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
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
                        "No logs yet.",
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
                        return _WaterHistoryTile(entry: _logs[index]);
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

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _FieldRow({
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

class _WaterHistoryTile extends StatelessWidget {
  final _WaterLogEntry entry;

  const _WaterHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, y').format(entry.date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerDark),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${entry.liters.toStringAsFixed(1)} L",
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

class _WaterLogEntry {
  final DateTime date;
  final double liters;

  _WaterLogEntry({required this.date, required this.liters});
}
