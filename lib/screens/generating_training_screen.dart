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
  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _pollTimeout = Duration(seconds: 90);
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _toastThreshold = Duration(minutes: 2);
  final DateTime _startedAt = DateTime.now();

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

      // Generation is asynchronous: trigger, then poll status until completion.
      await TrainingService.generateProgram(userId).timeout(_requestTimeout);
      await TrainingService.waitForGenerationToComplete(
        userId,
        pollInterval: _pollInterval,
        timeout: _pollTimeout,
      );

      // Refresh local program cache to reset progress for the new plan.
      bool synced = false;
      try {
        await TrainingService.fetchActiveProgram(userId)
            .timeout(const Duration(seconds: 20));
        synced = true;
      } on TrainingGenerationInProgressException {
        // If current endpoint still races, poll once more and fetch again.
        await TrainingService.waitForGenerationToComplete(
          userId,
          pollInterval: _pollInterval,
          timeout: const Duration(seconds: 30),
        );
        await TrainingService.fetchActiveProgram(userId)
            .timeout(const Duration(seconds: 20));
        synced = true;
      } catch (_) {
        // ignore; we'll clear progress cache below
      }
      if (!synced) {
        await TrainingProgressStorage.clearAll();
      }
      AccountStorage.notifyTrainingChanged();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
            (_) => false,
      );
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

      setState(() {
        _error = shouldShowToast && msg.isNotEmpty ? msg : null;
      });

      _retryCount++;

      if (_retryCount < _maxRetries) {
        Future.delayed(
          Duration(seconds: 2 * _retryCount),
              () {
            if (mounted) _generateTraining();
          },
        );
      }
    } finally {
      if (mounted) {
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
      await TrainingService.fetchActiveProgram(userId)
          .timeout(const Duration(seconds: 20));
      AccountStorage.notifyTrainingChanged();
      if (!mounted) return true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
            (_) => false,
      );
      return true;
    } catch (_) {
      return false;
    }
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
          body: t.translate("generating_training_body"),
          showError: _showFinalError,
          errorHeadline: t.translate("generating_error_title"),
          errorDetail: _error,
          note: t.translate("generating_training_note"),
        ),
      ),
    );
  }
}
