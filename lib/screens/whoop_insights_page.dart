import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/whoop_recovery_card.dart';
import '../widgets/dashboard/whoop_cycle_card.dart';
import '../widgets/dashboard/whoop_sleep_card.dart';
import '../widgets/dashboard/whoop_body_card.dart';
import 'whoop_recovery_detail_page.dart';
import 'whoop_cycle_detail_page.dart';
import '../services/whoop/whoop_cycle_service.dart';
import '../services/whoop/whoop_latest_service.dart';
import 'whoop_body_detail_page.dart';
import 'sleep_detail_page.dart';

class WhoopInsightsPage extends StatefulWidget {
  const WhoopInsightsPage({
    super.key,
    required this.loading,
    required this.linked,
    required this.linkedKnown,
    required this.recoveryScore,
    this.hideRecovery = false,
    this.hideCycle = false,
    this.hideBody = false,
    this.hideSleep = false,
    this.sleepHours,
    this.sleepScore,
    this.sleepGoal,
    this.sleepDelta,
    this.weightKg,
    this.cycleStrain,
  });

  final bool loading;
  final bool linked;
  final bool linkedKnown;
  final int? recoveryScore;
  final bool hideRecovery;
  final bool hideCycle;
  final bool hideBody;
  final bool hideSleep;
  final double? sleepHours;
  final int? sleepScore;
  final double? sleepGoal;
  final int? sleepDelta;
  final double? weightKg;
  final double? cycleStrain;

  @override
  State<WhoopInsightsPage> createState() => _WhoopInsightsPageState();
}

class _WhoopInsightsPageState extends State<WhoopInsightsPage> {
  bool _cycleLoading = false;
  double? _lastStrain;
  bool _hydrateLoading = false;
  double? _sleepHours;
  int? _sleepScore;
  int? _recoveryScore;
  double? _weightKg;

  @override
  void initState() {
    super.initState();
    _lastStrain = widget.cycleStrain;
    _sleepHours = widget.sleepHours;
    _sleepScore = widget.sleepScore;
    _recoveryScore = widget.recoveryScore;
    _weightKg = widget.weightKg;
    _loadLastStrain();
    _hydrateFromLatest();
  }

  Future<void> _hydrateFromLatest() async {
    if (!widget.linked) return;
    if (_sleepHours != null && _sleepScore != null && _recoveryScore != null && _weightKg != null) {
      return;
    }
    setState(() => _hydrateLoading = true);
    try {
      final data = await WhoopLatestService.fetch();
      if (!mounted || data == null) return;
      final sleep = data["sleep"];
      if (sleep is Map<String, dynamic>) {
        final score = sleep["score"];
        final stage = score is Map<String, dynamic> ? score["stage_summary"] : null;
        if (stage is Map<String, dynamic>) {
          final light = stage["total_light_sleep_time_milli"];
          final slow = stage["total_slow_wave_sleep_time_milli"];
          final rem = stage["total_rem_sleep_time_milli"];
          if (light is num && slow is num && rem is num) {
            final totalMs = light + slow + rem;
            if (totalMs > 0) {
              _sleepHours ??= totalMs / 3600000.0;
            }
          }
          final totalBed = stage["total_in_bed_time_milli"];
          if (_sleepScore == null &&
              totalBed is num &&
              totalBed > 0 &&
              light is num &&
              slow is num &&
              rem is num) {
            final sleepMs = light + slow + rem;
            _sleepScore = ((sleepMs / totalBed) * 100).round();
          }
        }
      }
      final recovery = data["recovery"];
      if (recovery is Map<String, dynamic>) {
        final score = recovery["score"];
        if (score is Map<String, dynamic>) {
          final raw = score["recovery_score"];
          if (raw is num) _recoveryScore ??= raw.round();
          if (raw is String) _recoveryScore ??= int.tryParse(raw);
        }
      }
      final body = data["body_measurement"];
      if (body is Map<String, dynamic>) {
        final raw = body["weight_kilogram"];
        if (raw is num) _weightKg ??= raw.toDouble();
        if (raw is String) _weightKg ??= double.tryParse(raw);
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _hydrateLoading = false);
    }
  }

  Future<void> _loadLastStrain() async {
    if (!widget.linked) return;
    setState(() => _cycleLoading = true);
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 6));
      final data = await WhoopCycleService().fetchDailyCycles(start: start, end: now);
      DateTime? latestDay;
      double? latestStrain;
      data.forEach((day, metrics) {
        final raw = metrics["strain"];
        final value = raw is num ? raw.toDouble() : double.tryParse("$raw");
        if (value == null) return;
        if (latestDay == null || day.isAfter(latestDay!)) {
          latestDay = day;
          latestStrain = value;
        }
      });
      if (!mounted) return;
      setState(() {
        _lastStrain = latestStrain;
        _cycleLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cycleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Whoop insights"),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!widget.hideSleep) ...[
              WhoopSleepCard(
                loading: widget.loading || _hydrateLoading,
                linked: widget.linked,
                linkedKnown: widget.linkedKnown,
                hours: _sleepHours ?? widget.sleepHours,
                score: _sleepScore ?? widget.sleepScore,
                goal: widget.sleepGoal,
                delta: widget.sleepDelta,
                showEfficiency: false,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SleepDetailPage(useWhoop: true)),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.hideRecovery) ...[
              SizedBox(
                width: double.infinity,
                child: WhoopRecoveryCard(
                  loading: widget.loading || _hydrateLoading,
                  linked: widget.linked,
                  score: _recoveryScore ?? widget.recoveryScore,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WhoopRecoveryDetailPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.hideCycle) ...[
              WhoopCycleCard(
                loading: widget.loading,
                linked: widget.linked,
                strain: _lastStrain,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhoopCycleDetailPage()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.hideBody)
              WhoopBodyCard(
                loading: widget.loading || _hydrateLoading,
                linked: widget.linked,
                weightKg: _weightKg ?? widget.weightKg,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhoopBodyDetailPage()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
