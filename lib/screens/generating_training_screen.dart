import 'dart:async';
import 'package:flutter/material.dart';
import '../services/training/training_service.dart';
import '../services/training/training_progress_storage.dart';
import '../core/account_storage.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/training_loading_indicator.dart';
import '../main/main_layout.dart';
import '../localization/app_localizations.dart';

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

      final msg = e.toString().replaceFirst('Exception: ', '');
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

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        body: Center(
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: TaqaUiScale.insetsLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: TaqaUiColors.white,
                  borderRadius: TaqaUiScale.radius(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: _showFinalError
                            ? TaqaUiColors.unnamedColorE93b3b.withValues(
                                alpha: 0.12,
                              )
                            : TaqaUiColors.unnamedColorE4e93b,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showFinalError
                            ? Icons.error_outline
                            : Icons.auto_awesome,
                        color: _showFinalError
                            ? TaqaUiColors.unnamedColorE93b3b
                            : TaqaUiColors.unnamedColor1c1d17,
                        size: TaqaUiScale.w(22),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(16)),
                    Text(
                      t.translate("generating_training_title"),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(17),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      t.translate("generating_training_body"),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    if (_isGenerating) ...[
                      const TrainingLoadingIndicator(),
                      SizedBox(height: TaqaUiScale.h(12)),
                      if (!_showFinalError)
                        Text(
                          t.translate("generating_waiting_hint"),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(11),
                            fontWeight: FontWeight.w400,
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                    ],
                    if (_showFinalError) ...[
                      SizedBox(height: TaqaUiScale.h(8)),
                      Text(
                        t.translate("generating_error_title"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.unnamedColorE93b3b,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: TaqaUiScale.h(6)),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(11),
                          color: TaqaUiColors.unnamedColorE93b3b.withValues(
                            alpha: 0.9,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    SizedBox(height: TaqaUiScale.h(16)),
                    Container(
                      padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: TaqaUiColors.unnamedColorE3e3e3,
                        borderRadius: TaqaUiScale.radius(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: TaqaUiColors.unnamedColor1c1d17,
                            size: TaqaUiScale.w(20),
                          ),
                          SizedBox(width: TaqaUiScale.w(10)),
                          Expanded(
                            child: Text(
                              t.translate("generating_training_note"),
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: TaqaUiScale.sp(12),
                                fontWeight: FontWeight.w400,
                                color: TaqaUiColors.unnamedColor1c1d17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
