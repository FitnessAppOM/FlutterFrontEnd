import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/account_storage.dart';
import '../../localization/app_localizations.dart';
import '../../screens/updating_plan_screen.dart';
import '../../services/training/training_service.dart';

/// Uses persisted server state, including after a cold start. Fetch failures
/// retain the last known warning and never prevent viewing the existing plan.
class PlanUpdateBanner extends StatefulWidget {
  const PlanUpdateBanner({super.key});

  @override
  State<PlanUpdateBanner> createState() => _PlanUpdateBannerState();
}

class _PlanUpdateBannerState extends State<PlanUpdateBanner>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _job;
  int? _userId;
  String? _dismissedAttempt;
  Timer? _timer;
  bool _loading = false;
  bool _opening = false;
  bool _dismissing = false;
  bool _foreground = true;

  static String _dismissalKey(int userId) =>
      'training_update_banner_dismissed_u$userId';

  // Retrying a job increments its attempt, so a new failure is visible again.
  String? get _attemptKey => _job?['job_id'] == null
      ? null
      : '${_job!['job_id']}:${_job!['attempt'] ?? 1}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AccountStorage.trainingChange.addListener(_onTrainingChanged);
    unawaited(_refresh());
  }

  void _onTrainingChanged() => unawaited(_refresh());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _refresh() async {
    if (_loading || _opening || !_foreground) return;
    _loading = true;
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null) return;
      final response = await TrainingService.fetchGenerationStatus(
        userId,
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      final raw = response['generation'];
      final job = raw is Map ? Map<String, dynamic>.from(raw) : null;
      final preferences = await SharedPreferences.getInstance();
      final currentUserId = await AccountStorage.getUserId();
      if (!mounted || currentUserId != userId) return;
      final wasPending =
          _job?['status'] == 'queued' || _job?['status'] == 'running';
      setState(() {
        _job = job;
        _userId = userId;
        _dismissedAttempt = preferences.getString(_dismissalKey(userId));
      });
      if (wasPending && job?['status'] == 'succeeded') {
        AccountStorage.notifyTrainingChanged();
      }
    } catch (_) {
      // Offline access to the old plan stays available.
    } finally {
      _loading = false;
      _timer?.cancel();
      if (mounted &&
          _foreground &&
          (_job?['status'] == 'queued' || _job?['status'] == 'running')) {
        _timer = Timer(const Duration(seconds: 15), _refresh);
      }
    }
  }

  Future<void> _dismiss() async {
    final userId = _userId;
    final attemptKey = _attemptKey;
    if (userId == null || attemptKey == null || _dismissing) return;
    setState(() => _dismissing = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _dismissalKey(userId),
        attemptKey,
      );
      if (mounted && saved && _userId == userId) {
        setState(() => _dismissedAttempt = attemptKey);
      }
    } catch (error) {
      debugPrint('Could not save training update dismissal: $error');
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AccountStorage.trainingChange.removeListener(_onTrainingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _job?['status'];
    if (!const {'queued', 'running', 'failed', 'superseded'}.contains(status)) {
      return const SizedBox.shrink();
    }
    final pending = status == 'queued' || status == 'running';
    if (!pending && _attemptKey != null && _dismissedAttempt == _attemptKey) {
      return const SizedBox.shrink();
    }
    final retryable = _job?['retryable'] == true;
    final t = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    t.translate(
                      pending
                          ? 'training_update_pending'
                          : retryable
                          ? 'training_update_failed'
                          : 'training_update_review_banner',
                    ),
                  ),
                ),
                if (!pending && _attemptKey != null)
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: _dismissing ? null : _dismiss,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (pending || retryable)
              TextButton(
                onPressed: _opening
                    ? null
                    : () async {
                        final jobId = int.tryParse('${_job?['job_id']}');
                        if (jobId == null) return;
                        setState(() => _opening = true);
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                UpdatingPlanScreen.resume(jobId: jobId),
                          ),
                        );
                        if (!mounted) return;
                        setState(() => _opening = false);
                        await _refresh();
                      },
                child: Text(
                  t.translate(
                    pending ? 'training_update_check' : 'generating_retry',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
