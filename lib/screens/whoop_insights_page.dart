import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/whoop_recovery_card.dart';
import '../widgets/dashboard/whoop_cycle_card.dart';
import '../widgets/dashboard/whoop_sleep_card.dart';
import '../widgets/dashboard/whoop_body_card.dart';
import 'whoop_recovery_detail_page.dart';
import 'whoop_cycle_detail_page.dart';
import '../services/whoop/whoop_widget_data_service.dart';
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
    _hydrateFromSnapshot();
  }

  Future<void> _hydrateFromSnapshot() async {
    if (!widget.linked) return;
    if (_sleepHours != null &&
        _sleepScore != null &&
        _recoveryScore != null &&
        _weightKg != null &&
        _lastStrain != null) {
      return;
    }
    setState(() => _hydrateLoading = true);
    try {
      final snapshot = await WhoopWidgetDataService().fetchForDate(DateTime.now());
      if (!mounted) return;
      _sleepHours ??= snapshot.sleepHours;
      _sleepScore ??= snapshot.sleepScore;
      _recoveryScore ??= snapshot.recoveryScore;
      _weightKg ??= snapshot.bodyWeightKg;
      _lastStrain ??= snapshot.cycleStrain;
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _hydrateLoading = false);
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
                loading: widget.loading || _hydrateLoading,
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
