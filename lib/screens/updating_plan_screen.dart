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
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
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
  bool _cooldownBlocked = false;
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

  bool _isAcceptedTrainingGeneration(dynamic payload) {
    if (payload is! Map) return false;
    final map = Map<String, dynamic>.from(payload);
    final status = map['status']?.toString().trim().toLowerCase();
    if (status == 'accepted') return true;
    final nested = map['generation'];
    if (nested is Map) {
      final nestedStatus = nested['status']?.toString().trim().toLowerCase();
      if (nestedStatus == 'accepted') return true;
    }
    return false;
  }

  Future<void> _run() async {
    setState(() {
      _isWorking = true;
      _error = null;
      _cooldownBlocked = false;
    });

    int? userId;
    try {
      userId = await AccountStorage.getUserId();
      if (userId == null) throw Exception("User not found");

      // Save profile first. Backend may now accept async training generation.
      final response = await ProfileApi.updateProfile(widget.profilePayload).timeout(_requestTimeout);
      if (!mounted) return;
      await AccountStorage.clearProfileEditBlockedUntil();

      final programRegenerated = response['program_regenerated'] == true;
      final regenError = response['program_regeneration_error']?.toString();
      final acceptedFromProfile = _isAcceptedTrainingGeneration(
        response['training_generation'],
      );

      // New backend: poll generation status when accepted from profile/update.
      if (acceptedFromProfile) {
        await TrainingService.waitForGenerationToComplete(
          userId,
          pollInterval: _pollInterval,
          timeout: _pollTimeout,
        );
      } else if (!programRegenerated && regenError == null) {
        // Legacy fallback: explicit generate, then poll status endpoint.
        await TrainingService.generateProgram(userId).timeout(_requestTimeout);
        await TrainingService.waitForGenerationToComplete(
          userId,
          pollInterval: _pollInterval,
          timeout: _pollTimeout,
        );
      }
      if (!mounted) return;

      // Refresh local program cache to reset progress for the new plan.
      bool synced = false;
      try {
        await TrainingService.fetchActiveProgram(userId)
            .timeout(const Duration(seconds: 20));
        synced = true;
      } on TrainingGenerationInProgressException {
        await TrainingService.waitForGenerationToComplete(
          userId,
          pollInterval: _pollInterval,
          timeout: const Duration(seconds: 30),
        );
        await TrainingService.fetchActiveProgram(userId)
            .timeout(const Duration(seconds: 20));
        synced = true;
      } catch (_) {}
      if (!synced) {
        await TrainingProgressStorage.clearAll();
      }
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
      final dietPending = response['diet_pending'] == true ||
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
      await TrainingService.waitForGenerationToComplete(
        userId,
        pollInterval: _pollInterval,
        timeout: const Duration(seconds: 20),
      );
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

    return PopScope(
      canPop: _cooldownBlocked,
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
                      t.translate("updating_plan_title"),
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
                      t.translate("updating_plan_body"),
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
                    if (_isWorking) ...[
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
                        _cooldownBlocked
                            ? "Profile edit is temporarily locked"
                            : t.translate("generating_error_title"),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(13),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.unnamedColorE93b3b,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_cooldownBlocked && _cooldownUntil != null) ...[
                        SizedBox(height: TaqaUiScale.h(6)),
                        Text(
                          "Profile updates are limited to once each 30 days.",
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(12),
                            fontWeight: FontWeight.w600,
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                      SizedBox(height: TaqaUiScale.h(16)),
                      _UpdatingPlanActionButton(
                        label: _cooldownBlocked
                            ? "Back"
                            : t.translate("generating_retry"),
                        onTap: () {
                          if (!_cooldownBlocked) {
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
                            MaterialPageRoute(
                              builder: (_) => const MainLayout(),
                            ),
                            (_) => false,
                          );
                        },
                      ),
                    ],
                    if (!_cooldownBlocked) ...[
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
                                t.translate("updating_plan_note"),
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

class _UpdatingPlanActionButton extends StatelessWidget {
  const _UpdatingPlanActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TaqaUiColors.unnamedColorE4e93b,
      borderRadius: TaqaUiScale.radius(12),
      child: InkWell(
        borderRadius: TaqaUiScale.radius(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: TaqaUiScale.h(46),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(14),
              fontWeight: FontWeight.w700,
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
        ),
      ),
    );
  }
}
