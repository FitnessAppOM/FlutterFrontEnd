import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/fitbit/fitbit_activity_service.dart';
import '../services/fitbit/fitbit_heart_service.dart';
import '../services/fitbit/fitbit_sleep_service.dart';
import '../services/fitbit/fitbit_summary_service.dart';
import '../services/fitbit/fitbit_vitals_service.dart';
import '../services/fitbit/fitbit_body_service.dart';
import '../widgets/dashboard/fitbit_daily_activity_card.dart';
import '../widgets/dashboard/fitbit_daily_activity_sheet.dart';
import '../widgets/dashboard/fitbit_heart_card.dart';
import '../widgets/dashboard/fitbit_heart_sheet.dart';
import '../widgets/dashboard/fitbit_sleep_card.dart';
import '../widgets/dashboard/fitbit_sleep_sheet.dart';
import '../widgets/dashboard/fitbit_vitals_card.dart';
import '../widgets/dashboard/fitbit_vitals_sheet.dart';
import '../widgets/dashboard/fitbit_body_card.dart';
import '../widgets/dashboard/fitbit_body_sheet.dart';

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
    required this.vitals,
    required this.vitalsLast,
    required this.body,
    required this.bodyLast,
    required this.date,
    this.hideActivity = false,
    this.hideHeart = false,
    this.hideSleep = false,
    this.hideVitals = false,
    this.hideBody = false,
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
  final FitbitVitalsSummary? vitals;
  final FitbitVitalsSummary? vitalsLast;
  final FitbitBodySummary? body;
  final FitbitBodySummary? bodyLast;
  final DateTime date;
  final bool hideActivity;
  final bool hideHeart;
  final bool hideSleep;
  final bool hideVitals;
  final bool hideBody;

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
  FitbitVitalsSummary? _vitals;
  FitbitVitalsSummary? _vitalsLast;
  FitbitBodySummary? _body;
  FitbitBodySummary? _bodyLast;
  bool _activityLoading = false;
  bool _heartLoading = false;
  bool _sleepLoading = false;
  bool _vitalsLoading = false;
  bool _bodyLoading = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.activity;
    _activityLast = widget.activityLast;
    _heart = widget.heart;
    _heartLast = widget.heartLast;
    _sleep = widget.sleep;
    _sleepLast = widget.sleepLast;
    _vitals = widget.vitals;
    _vitalsLast = widget.vitalsLast;
    _body = widget.body;
    _bodyLast = widget.bodyLast;
    _activityLoading = widget.activityLoading;
    _heartLoading = widget.heartLoading;
    _sleepLoading = widget.sleepLoading;
    _vitalsLoading = false;
    _bodyLoading = false;
    _refreshOnOpen();
  }

  Future<void> _refreshOnOpen() async {
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      if (!widget.hideActivity) _activityLoading = true;
      if (!widget.hideHeart) _heartLoading = true;
      if (!widget.hideSleep) _sleepLoading = true;
      if (!widget.hideVitals) _vitalsLoading = true;
      if (!widget.hideBody) _bodyLoading = true;
    });
    try {
      final bundle = await FitbitSummaryService().fetchSummary(widget.date);
      if (!mounted) return;
      setState(() {
        if (!widget.hideActivity) {
          _activity = bundle?.activity;
          _activityLast = bundle?.activity ?? _activityLast;
          _activityLoading = false;
        }
        if (!widget.hideHeart) {
          _heart = bundle?.heart;
          _heartLast = bundle?.heart ?? _heartLast;
          _heartLoading = false;
        }
        if (!widget.hideSleep) {
          _sleep = bundle?.sleep;
          _sleepLast = bundle?.sleep ?? _sleepLast;
          _sleepLoading = false;
        }
        if (!widget.hideVitals) {
          _vitals = bundle?.vitals;
          _vitalsLast = bundle?.vitals ?? _vitalsLast;
          _vitalsLoading = false;
        }
        if (!widget.hideBody) {
          _body = bundle?.body;
          _bodyLast = bundle?.body ?? _bodyLast;
          _bodyLoading = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (!widget.hideActivity) _activityLoading = false;
        if (!widget.hideHeart) _heartLoading = false;
        if (!widget.hideSleep) _sleepLoading = false;
        if (!widget.hideVitals) _vitalsLoading = false;
        if (!widget.hideBody) _bodyLoading = false;
      });
    }
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

  Future<void> _loadVitals() async {
    setState(() => _vitalsLoading = true);
    try {
      final summary = await FitbitVitalsService().fetchSummary(widget.date);
      if (!mounted) return;
      setState(() {
        _vitals = summary;
        _vitalsLast = summary ?? _vitalsLast;
      });
    } catch (_) {
      // ignore fetch errors; keep last
    } finally {
      if (mounted) setState(() => _vitalsLoading = false);
    }
  }

  Future<void> _loadBody() async {
    setState(() => _bodyLoading = true);
    try {
      final summary = await FitbitBodyService().fetchSummary(widget.date);
      if (!mounted) return;
      setState(() {
        _body = summary;
        _bodyLast = summary ?? _bodyLast;
      });
    } catch (_) {
      // ignore fetch errors; keep last
    } finally {
      if (mounted) setState(() => _bodyLoading = false);
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
    final vitalsSummary = _vitalsLoading ? (_vitalsLast ?? _vitals) : _vitals;
    final vitalsBusy = _vitalsLoading && vitalsSummary == null;
    final bodySummary = _bodyLoading ? (_bodyLast ?? _body) : _body;
    final bodyBusy = _bodyLoading && bodySummary == null;

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
            if (!widget.hideVitals) ...[
              const SizedBox(height: 12),
              FitbitVitalsCard(
                loading: vitalsBusy,
                spo2Percent: vitalsSummary?.spo2Percent,
                skinTempC: vitalsSummary?.skinTempC,
                breathingRate: vitalsSummary?.breathingRate,
                ecgSummary: vitalsSummary?.ecgSummary,
                ecgAvgHr: vitalsSummary?.ecgAvgHr,
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => FitbitVitalsSheet(summary: vitalsSummary),
                  );
                },
              ),
            ],
            if (!widget.hideBody) ...[
              const SizedBox(height: 12),
              FitbitBodyCard(
                loading: bodyBusy,
                weightKg: bodySummary?.weightKg,
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => FitbitBodySheet(summary: bodySummary),
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
