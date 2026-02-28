import 'dart:async';
import 'package:flutter/material.dart';
import '../services/training/training_service.dart';
import '../services/training/training_progress_storage.dart';
import '../core/account_storage.dart';
import '../widgets/app_toast.dart';
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
  // Allow longer server processing before we consider it a timeout.
  static const Duration _timeout = Duration(seconds: 60);
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

      // Training program is returned immediately; diet is generated in background.
      await TrainingService.generateProgram(userId)
          .timeout(_timeout);

      // Refresh local program cache to reset progress for the new plan.
      bool synced = false;
      try {
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.12),
                cs.surfaceVariant.withOpacity(0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _showFinalError ? Icons.error_outline : Icons.auto_awesome,
                              color: _showFinalError ? cs.error : cs.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.translate("generating_training_title"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.translate("generating_training_body"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (_isGenerating) ...[
                        const TrainingLoadingIndicator(),
                        const SizedBox(height: 12),
                        if (!_showFinalError)
                          Text(
                            t.translate("generating_waiting_hint"),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6),
                            ),
                          ),
                      ],
                      if (_showFinalError) ...[
                        const SizedBox(height: 8),
                        Text(
                          t.translate("generating_error_title"),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.error.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.translate("generating_training_note"),
                                style: theme.textTheme.bodyMedium,
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
      ),
    );
  }
}
