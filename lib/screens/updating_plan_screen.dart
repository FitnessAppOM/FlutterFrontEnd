import 'dart:async';
import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../core/diet_regeneration_flag.dart';
import '../localization/app_localizations.dart';
import '../main/main_layout.dart';
import '../services/auth/profile_service.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/diet_targets_storage.dart';
import '../services/training/training_service.dart';
import '../services/training/training_progress_storage.dart';
import '../widgets/app_toast.dart';
import '../widgets/training_loading_indicator.dart';

/// Shown after editing profile when training days change.
/// Saves the profile first, then regenerates training + diet.
class UpdatingPlanScreen extends StatefulWidget {
  const UpdatingPlanScreen({
    super.key,
    required this.profilePayload,
  });

  final Map<String, dynamic> profilePayload;

  @override
  State<UpdatingPlanScreen> createState() => _UpdatingPlanScreenState();
}

class _UpdatingPlanScreenState extends State<UpdatingPlanScreen> {
  bool _isWorking = true;
  String? _error;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 60);
  static const Duration _toastThreshold = Duration(minutes: 2);
  final DateTime _startedAt = DateTime.now();

  bool get _showFinalError => _error != null && _retryCount >= _maxRetries;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _isWorking = true;
      _error = null;
    });

    int? userId;
    try {
      userId = await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      // 1) Save profile
      await ProfileApi.updateProfile(widget.profilePayload).timeout(_timeout);
      if (!mounted) return;

      // 2) Regenerate training (AI); diet is generated in background
      await TrainingService.generateProgram(userId).timeout(_timeout);
      if (!mounted) return;

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

      // 3) Pre-open / fetch today's meals (best-effort)
      try {
        await DietService.fetchMealsForDate(
          userId,
          date: DateTime.now(),
          autoOpen: true,
        ).timeout(const Duration(seconds: 20));
      } catch (_) {
        // ignore
      }

      if (!mounted) return;
      DietRegenerationFlag.setRegenerating();
      await DietTargetsStorage.clearTargets();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // If generation succeeded but response timed out, try verifying readiness.
      if (userId != null) {
        final navigated = await _tryNavigateIfReady(userId);
        if (navigated) return;
      }

      if (!mounted) return;

      final msg = e.toString().replaceFirst('Exception: ', '');
      final elapsed = DateTime.now().difference(_startedAt);
      final shouldShowToast = elapsed >= _toastThreshold;
      if (shouldShowToast && msg.isNotEmpty) {
        AppToast.show(context, msg, type: AppToastType.error);
      }

      setState(() {
        _error = shouldShowToast && msg.isNotEmpty ? msg : null;
      });

      _retryCount++;
      if (_retryCount < _maxRetries) {
        Future.delayed(Duration(seconds: 2 * _retryCount), () {
          if (mounted) _run();
        });
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Navigate if training program is ready (diet may still be generating in background).
  Future<bool> _tryNavigateIfReady(int userId) async {
    try {
      await TrainingService.fetchActiveProgram(userId).timeout(const Duration(seconds: 20));
      AccountStorage.notifyTrainingChanged();
      if (!mounted) return true;
      DietRegenerationFlag.setRegenerating();
      await DietTargetsStorage.clearTargets();
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withValues(alpha: 0.12),
                cs.surfaceContainerHighest.withValues(alpha: 0.35),
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
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 16),
                      ),
                    ],
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _showFinalError ? Icons.error_outline : Icons.auto_awesome,
                          color: _showFinalError ? cs.error : cs.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.translate("updating_plan_title"),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.translate("updating_plan_body"),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (_isWorking) ...[
                        const TrainingLoadingIndicator(),
                        const SizedBox(height: 12),
                        if (!_showFinalError)
                          Text(
                            t.translate("generating_waiting_hint"),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
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
                            color: cs.error.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _retryCount = 0;
                              _run();
                            },
                            child: Text(t.translate("generating_retry")),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t.translate("updating_plan_note"),
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
