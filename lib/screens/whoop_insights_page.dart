import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/whoop_recovery_card.dart';
import '../widgets/dashboard/whoop_cycle_card.dart';
import '../widgets/dashboard/whoop_body_card.dart';
import 'whoop_recovery_detail_page.dart';
import 'whoop_cycle_detail_page.dart';
import '../services/whoop/whoop_cycle_service.dart';
import 'whoop_body_detail_page.dart';

class WhoopInsightsPage extends StatefulWidget {
  const WhoopInsightsPage({
    super.key,
    required this.loading,
    required this.linked,
    required this.recoveryScore,
  });

  final bool loading;
  final bool linked;
  final int? recoveryScore;

  @override
  State<WhoopInsightsPage> createState() => _WhoopInsightsPageState();
}

class _WhoopInsightsPageState extends State<WhoopInsightsPage> {
  bool _cycleLoading = false;
  double? _lastStrain;

  @override
  void initState() {
    super.initState();
    _loadLastStrain();
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
            SizedBox(
              width: double.infinity,
              child: WhoopRecoveryCard(
                loading: widget.loading,
                linked: widget.linked,
                score: widget.recoveryScore,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WhoopRecoveryDetailPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            WhoopCycleCard(
              loading: widget.loading || _cycleLoading,
              linked: widget.linked,
              strain: _lastStrain,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WhoopCycleDetailPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            WhoopBodyCard(
              loading: widget.loading,
              linked: widget.linked,
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
