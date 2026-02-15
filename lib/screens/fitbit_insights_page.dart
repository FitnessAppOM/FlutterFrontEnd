import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/fitbit/fitbit_activity_service.dart';
import '../services/fitbit/fitbit_heart_service.dart';
import '../services/fitbit/fitbit_sleep_service.dart';
import '../widgets/dashboard/fitbit_daily_activity_card.dart';
import '../widgets/dashboard/fitbit_daily_activity_sheet.dart';
import '../widgets/dashboard/fitbit_heart_card.dart';
import '../widgets/dashboard/fitbit_heart_sheet.dart';
import '../widgets/dashboard/fitbit_sleep_card.dart';
import '../widgets/dashboard/fitbit_sleep_sheet.dart';

class FitbitInsightsPage extends StatefulWidget {
  const FitbitInsightsPage({
    super.key,
    required this.activityLoading,
    required this.heartLoading,
    required this.sleepLoading,
    required this.activity,
    required this.activityLast,
    required this.heart,
    required this.heartLast,
    required this.sleep,
    required this.sleepLast,
    required this.date,
    this.hideActivity = false,
    this.hideHeart = false,
    this.hideSleep = false,
  });

  final bool activityLoading;
  final bool heartLoading;
  final bool sleepLoading;
  final FitbitActivitySummary? activity;
  final FitbitActivitySummary? activityLast;
  final FitbitHeartSummary? heart;
  final FitbitHeartSummary? heartLast;
  final FitbitSleepSummary? sleep;
  final FitbitSleepSummary? sleepLast;
  final DateTime date;
  final bool hideActivity;
  final bool hideHeart;
  final bool hideSleep;

  @override
  State<FitbitInsightsPage> createState() => _FitbitInsightsPageState();
}

class _FitbitInsightsPageState extends State<FitbitInsightsPage> {
  FitbitActivitySummary? _activity;
  FitbitActivitySummary? _activityLast;
  FitbitHeartSummary? _heart;
  FitbitHeartSummary? _heartLast;
  FitbitSleepSummary? _sleep;
  FitbitSleepSummary? _sleepLast;
  bool _activityLoading = false;
  bool _heartLoading = false;
  bool _sleepLoading = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _activityLast = widget.activityLast;
    _heart = widget.heart;
    _heartLast = widget.heartLast;
    _sleep = widget.sleep;
    _sleepLast = widget.sleepLast;
    _activityLoading = widget.activityLoading;
    _heartLoading = widget.heartLoading;
    _sleepLoading = widget.sleepLoading;
    _refreshOnOpen();
  }

  Future<void> _refreshOnOpen() async {
    final futures = <Future<void>>[];
    if (!widget.hideActivity) {
      futures.add(_loadActivity());
    }
    if (!widget.hideHeart) {
      futures.add(_loadHeart());
    }
    if (!widget.hideSleep) {
      futures.add(_loadSleep());
    }
    await Future.wait(futures);
  }

  Future<void> _loadActivity() async {
    setState(() => _activityLoading = true);
    try {
      final summary = await FitbitActivityService().fetchActivity(widget.date);
      if (!mounted) return;
      setState(() {
        _activity = summary;
        _activityLast = summary ?? _activityLast;
      });
    } catch (_) {
      // ignore fetch errors; keep last
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadHeart() async {
    setState(() => _heartLoading = true);
    try {
      final summary = await FitbitHeartService().fetchSummary(widget.date);
      if (!mounted) return;
      setState(() {
        _heart = summary;
        _heartLast = summary ?? _heartLast;
      });
    } catch (_) {
      // ignore fetch errors; keep last
    } finally {
      if (mounted) setState(() => _heartLoading = false);
    }
  }

  Future<void> _loadSleep() async {
    setState(() => _sleepLoading = true);
    try {
      final summary = await FitbitSleepService().fetchSummary(widget.date);
      if (!mounted) return;
      setState(() {
        _sleep = summary;
        _sleepLast = summary ?? _sleepLast;
      });
    } catch (_) {
      // ignore fetch errors; keep last
    } finally {
      if (mounted) setState(() => _sleepLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activitySummary = _activityLoading ? (_activityLast ?? _activity) : _activity;
    final activityBusy = _activityLoading && activitySummary == null;
    final heartSummary = _heartLoading ? (_heartLast ?? _heart) : _heart;
    final heartBusy = _heartLoading && heartSummary == null;
    final sleepSummary = _sleepLoading ? (_sleepLast ?? _sleep) : _sleep;
    final sleepBusy = _sleepLoading && sleepSummary == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Fitbit insights"),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!widget.hideActivity) ...[
              FitbitDailyActivityCard(
                loading: activityBusy,
                steps: activitySummary?.steps,
                distanceKm: activitySummary?.distance,
                calories: activitySummary?.calories,
                activeMinutes: activitySummary?.activeMinutes,
                onTap: activitySummary == null
                    ? null
                    : () async {
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => FitbitDailyActivitySheet(
                            summary: activitySummary,
                            date: widget.date,
                          ),
                        );
                      },
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.hideHeart) ...[
              FitbitHeartCard(
                loading: heartBusy,
                restingHr: heartSummary?.restingHr,
                hrvRmssd: heartSummary?.hrvRmssd,
                vo2Max: heartSummary?.vo2Max,
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => FitbitHeartSheet(
                      restingHr: heartSummary?.restingHr,
                      hrvRmssd: heartSummary?.hrvRmssd,
                      vo2Max: heartSummary?.vo2Max,
                      zones: heartSummary?.zones ?? const [],
                      date: widget.date,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            if (!widget.hideSleep) ...[
              FitbitSleepCard(
                loading: sleepBusy,
                minutesAsleep: sleepSummary?.totalMinutesAsleep,
                minutesInBed: sleepSummary?.totalTimeInBed,
                goalMinutes: sleepSummary?.sleepGoalMinutes,
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => FitbitSleepSheet(
                      summary: sleepSummary,
                      date: widget.date,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
