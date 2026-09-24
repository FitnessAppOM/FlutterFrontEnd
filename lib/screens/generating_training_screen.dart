import 'dart:async';
import 'package:flutter/material.dart';
import '../services/training/training_service.dart';
import '../services/training/training_progress_storage.dart';
import '../core/account_storage.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../widgets/taqa_bolt_loading_screen.dart';
import '../main/main_layout.dart';
import '../localization/app_localizations.dart';
import '../core/user_friendly_error.dart';
import '../TaqaUI/screens/taqa_subscription_page.dart';

class GeneratingTrainingScreen extends StatefulWidget {
  const GeneratingTrainingScreen({super.key});

  @override
  State<GeneratingTrainingScreen> createState() =>
      _GeneratingTrainingScreenState();
}

class _GeneratingTrainingScreenState extends State<GeneratingTrainingScreen> {
  bool _isGenerating = true;
  String? _error;
  int _retryCount = 0;
  bool _checkedForExistingProgram = false;
  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _pollTimeout = Duration(seconds: 90);
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _toastThreshold = Duration(minutes: 2);
  DateTime _startedAt = DateTime.now();

  bool get _showFinalError => _error != null && _retryCount >= _maxRetries;

  @override
  void initState() {
    super.initState();
    _generateTraining();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _generateTraining() async {
    // Keep the bolt visible while an automatic retry is queued.
    var retryScheduled = false;
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    int? userId;
    try {
      userId = await AccountStorage.getUserId();
      if (userId == null) {
        throw Exception("User not found");
      }

      // On a restart, resume this stage instead of starting duplicate work.
      // A completed plan means the generation step already finished; a 202
      // means an existing generation job should be polled to completion.
      if (!_checkedForExistingProgram) {
        _checkedForExistingProgram = true;
        try {
          await TrainingService.ensureGeneratedProgramReady(
            userId,
          ).timeout(const Duration(seconds: 20));
          AccountStorage.notifyTrainingChanged();
          if (!mounted) return;
          await _continueToSubscription();
          return;
        } on TrainingGenerationInProgressException {
          await TrainingService.waitForGenerationToComplete(
            userId,
            pollInterval: _pollInterval,
            timeout: _pollTimeout,
          );
          await TrainingService.ensureGeneratedProgramReady(
            userId,
          ).timeout(const Duration(seconds: 20));
          AccountStorage.notifyTrainingChanged();
          if (!mounted) return;
          await _continueToSubscription();
          return;
        } catch (_) {
          // No completed/in-progress plan exists, so start initial generation.
        }
      }

      // Generation is asynchronous: trigger, then poll status until completion.
      await TrainingService.generateProgram(userId).timeout(_requestTimeout);
      await TrainingService.waitForGenerationToComplete(
        userId,
        pollInterval: _pollInterval,
        timeout: _pollTimeout,
      );

      // Confirm that generation persisted a plan without exposing the paid
      // program contents before checkout.
      bool synced = false;
      try {
        await TrainingService.ensureGeneratedProgramReady(
          userId,
        ).timeout(const Duration(seconds: 20));
        synced = true;
      } on TrainingGenerationInProgressException {
        // If current endpoint still races, poll once more and fetch again.
        await TrainingService.waitForGenerationToComplete(
          userId,
          pollInterval: _pollInterval,
          timeout: const Duration(seconds: 30),
        );
        await TrainingService.ensureGeneratedProgramReady(
          userId,
        ).timeout(const Duration(seconds: 20));
        synced = true;
      } catch (_) {
        // ignore; we'll clear progress cache below
      }
      if (!synced) {
        await TrainingProgressStorage.clearAll();
      }
      AccountStorage.notifyTrainingChanged();

      if (!mounted) return;

      await _continueToSubscription();
    } catch (e) {
      if (!mounted) return;

      if (userId != null) {
        final navigated = await _tryNavigateIfProgramAndDietReady(userId);
        if (navigated) return;
      }

      if (!mounted) return;

      final msg = userFriendlyErrorMessage(e);
      final elapsed = DateTime.now().difference(_startedAt);

      final shouldShowToast = elapsed >= _toastThreshold;
      if (shouldShowToast) {
        AppToast.show(context, msg, type: AppToastType.error);
      }

      final canRetry = !isMissingQuestionnaireError(e);
      final isFinalAttempt = !canRetry || _retryCount + 1 >= _maxRetries;

      setState(() {
        _error = (shouldShowToast || isFinalAttempt) && msg.isNotEmpty
            ? msg
            : null;
      });

      _retryCount++;

      if (canRetry && _retryCount < _maxRetries) {
        retryScheduled = true;
        Future.delayed(Duration(seconds: 2 * _retryCount), () {
          if (mounted) _generateTraining();
        });
      } else {
        _retryCount = _maxRetries;
      }
    } finally {
      if (mounted && !retryScheduled) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Navigate into app if training program is ready (diet may still be generating in background).
  Future<bool> _tryNavigateIfProgramAndDietReady(int userId) async {
    try {
      await TrainingService.waitForGenerationToComplete(
        userId,
        pollInterval: _pollInterval,
        timeout: const Duration(seconds: 20),
      );
      await TrainingService.ensureGeneratedProgramReady(
        userId,
      ).timeout(const Duration(seconds: 20));
      AccountStorage.notifyTrainingChanged();
      if (!mounted) return true;
      await _continueToSubscription();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A generated first plan is unlocked only after a completed or restored
  /// App Store subscription. The subscription route cannot be dismissed.
  Future<void> _continueToSubscription() async {
    if (!mounted) return;
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TaqaSubscriptionPage(mandatory: true),
      ),
    );
    if (!mounted || subscribed != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainLayout()),
      (_) => false,
    );
  }

  void _retry() {
    if (_isGenerating) return;
    _retryCount = 0;
    _checkedForExistingProgram = false;
    _startedAt = DateTime.now();
    _generateTraining();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    if (_isGenerating) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: TaqaBoltLoadingScreen.background,
          body: TaqaBoltLoadingScreen(
            note: t.translate("generating_training_note"),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TaqaBoltLoadingScreen.background,
        body: TaqaBoltStatusScreen(
          title: t.translate("generating_training_title"),
          body: t.translate(
            _showFinalError
                ? "generating_error_body"
                : "generating_training_body",
          ),
          showError: _showFinalError,
          errorHeadline: t.translate("generating_error_title"),
          errorDetail: _error,
          buttonLabel: _showFinalError ? t.translate("generating_retry") : null,
          onButtonTap: _showFinalError ? _retry : null,
          note: t.translate("generating_training_note"),
        ),
      ),
    );
  }
}
