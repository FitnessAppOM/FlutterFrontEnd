import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../core/diet_regeneration_flag.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/diet_targets_storage.dart';
import '../services/training/training_service.dart';
import '../services/training/plan_update_coordinator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../widgets/taqa_bolt_loading_screen.dart';
import '../core/user_friendly_error.dart';

/// Shown after editing profile when training days change.
/// Saves the profile first, then regenerates training + diet.
class UpdatingPlanScreen extends StatefulWidget {
  const UpdatingPlanScreen({super.key, required this.profilePayload})
    : resumeJobId = null;
  const UpdatingPlanScreen.resume({super.key, required int jobId})
    : resumeJobId = jobId,
      profilePayload = null;

  final Map<String, dynamic>? profilePayload;
  final int? resumeJobId;

  @override
  State<UpdatingPlanScreen> createState() => _UpdatingPlanScreenState();
}

class _UpdatingPlanScreenState extends State<UpdatingPlanScreen> {
  bool _isWorking = true;
  String? _error;
  bool _cooldownBlocked = false;
  bool _recoveryBlocked = false;
  PlanUpdateCoordinator? _coordinator;
  final String _requestKey =
      'profile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  DateTime? _cooldownUntil;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _pollTimeout = Duration(seconds: 90);
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _toastThreshold = Duration(minutes: 2);
  final DateTime _startedAt = DateTime.now();

  bool get _showFinalError => _error != null && _retryCount >= _maxRetries;

  String _formatDateTimeForMessage(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    // A failed attempt can be retried automatically. Keep the bolt visible
    // during that pause instead of falling through to the non-loading status
    // screen between attempts.
    var retryScheduled = false;
    setState(() {
      _isWorking = true;
      _error = null;
      _cooldownBlocked = false;
    });

    int? userId;
    try {
      userId = await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      _coordinator ??= PlanUpdateCoordinator(
        jobId: widget.resumeJobId,
        saveProfile: () => ProfileApi.updateProfile(
          widget.profilePayload!,
          requestKey: _requestKey,
        ).timeout(_requestTimeout),
        readJob: (jobId) => TrainingService.fetchGenerationStatus(
          userId!,
          jobId: jobId,
        ).timeout(_requestTimeout),
        retryJob: (jobId) async {
          await TrainingService.generateProgram(
            userId!,
            retryJobId: jobId,
          ).timeout(_requestTimeout);
        },
        fetchProgram: () => TrainingService.fetchActiveProgram(
          userId!,
        ).timeout(_requestTimeout),
        pollInterval: _pollInterval,
        pollTimeout: _pollTimeout,
      );
      await _coordinator!.run();
      if (!mounted) return;
      final response = _coordinator!.savedProfile ?? const <String, dynamic>{};
      await AccountStorage.clearProfileEditBlockedUntil();
      AccountStorage.notifyTrainingChanged();

      // Pre-open / fetch today's meals (best-effort)
      try {
        await DietService.fetchMealsForDate(
          userId,
          date: DateTime.now(),
          autoOpen: true,
        ).timeout(const Duration(seconds: 20));
      } catch (_) {}

      if (!mounted) return;

      // Diet is regenerating in background
      final dietPending =
          response['diet_pending'] == true ||
          response['diet_needs_regeneration'] == true;
      if (dietPending) {
        DietRegenerationFlag.setRegenerating();
      }
      await DietTargetsStorage.clearTargets();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      if (e is ProfileUpdateCooldownException) {
        final next = e.nextAllowedAt;
        if (next != null) {
          await AccountStorage.setProfileEditBlockedUntil(next);
        }
        final msg = next != null
            ? "Next edit available at ${_formatDateTimeForMessage(next)}"
            : e.detail;
        setState(() {
          _error = msg;
          _cooldownBlocked = true;
          _cooldownUntil = next;
          _retryCount = _maxRetries;
        });
        return;
      }

      if (!mounted) return;

      final t = AppLocalizations.of(context);
      final msg = e is PlanUpdateException
          ? t.translate(
              e.retryable ? 'training_update_failed' : 'training_update_review',
            )
          : e is TrainingApiException && e.statusCode == 409
          ? t.translate('training_update_review')
          : e is TimeoutException && _coordinator?.jobId != null
          ? t.translate('training_update_pending')
          : userFriendlyErrorMessage(e);
      final elapsed = DateTime.now().difference(_startedAt);
      final shouldShowToast = elapsed >= _toastThreshold;
      final canRetry =
          !isMissingQuestionnaireError(e) &&
          (e is! PlanUpdateException || e.retryable) &&
          (e is! TrainingApiException || e.isRetryable);
      _recoveryBlocked = !canRetry;
      final isFinalAttempt = !canRetry || _retryCount + 1 >= _maxRetries;
      if (shouldShowToast && msg.isNotEmpty) {
        AppToast.show(context, msg, type: AppToastType.error);
      }

      setState(() {
        _error = (shouldShowToast || isFinalAttempt) && msg.isNotEmpty
            ? msg
            : null;
      });

      _retryCount++;
      if (canRetry && _retryCount < _maxRetries) {
        retryScheduled = true;
        Future.delayed(Duration(seconds: 2 * _retryCount), () {
          if (mounted) _run();
        });
      } else {
        _retryCount = _maxRetries;
      }
    } finally {
      if (mounted && !retryScheduled) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_isWorking) {
      return PopScope(
        canPop: !_isWorking,
        child: Scaffold(
          backgroundColor: TaqaBoltLoadingScreen.background,
          body: TaqaBoltLoadingScreen(note: t.translate("updating_plan_note")),
        ),
      );
    }

    return PopScope(
      canPop: !_isWorking,
      child: Scaffold(
        backgroundColor: TaqaBoltLoadingScreen.background,
        body: TaqaBoltStatusScreen(
          title: t.translate("updating_plan_title"),
          body: t.translate("updating_plan_body"),
          showError: _showFinalError,
          errorHeadline: _cooldownBlocked
              ? t.translate("profile_edit_locked_title")
              : t.translate("generating_error_title"),
          cooldownNote: _cooldownBlocked && _cooldownUntil != null
              ? t.translate("profile_edit_locked_note")
              : null,
          errorDetail: _error,
          buttonLabel: _showFinalError
              ? ((_cooldownBlocked || _recoveryBlocked)
                    ? t.translate("back")
                    : t.translate("generating_retry"))
              : null,
          onButtonTap: () {
            if (!_cooldownBlocked && !_recoveryBlocked) {
              _retryCount = 0;
              _run();
              return;
            }
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop(false);
              return;
            }
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const MainLayout()),
              (_) => false,
            );
          },
          note: _cooldownBlocked ? null : t.translate("updating_plan_note"),
        ),
      ),
    );
  }
}
