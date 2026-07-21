import 'dart:async';
import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/diet_targets_storage.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/training_loading_indicator.dart';
import '../main/main_layout.dart';
import '../core/user_friendly_error.dart';

/// Shown after editing profile when only goal or nutrition (diet type) changed.
/// Saves the profile (backend regenerates diet in background), then polls until
/// diet targets are no longer stale.
class UpdatingDietScreen extends StatefulWidget {
  const UpdatingDietScreen({super.key, required this.profilePayload});

  final Map<String, dynamic> profilePayload;

  @override
  State<UpdatingDietScreen> createState() => _UpdatingDietScreenState();
}

class _UpdatingDietScreenState extends State<UpdatingDietScreen> {
  bool _isWorking = true;
  String? _error;
  bool _cooldownBlocked = false;
  DateTime? _cooldownUntil;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 90);
  static const Duration _toastThreshold = Duration(minutes: 2);
  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(seconds: 45);
  final DateTime _startedAt = DateTime.now();
  Timer? _pollTimer;

  bool get _showFinalError => _error != null && _retryCount >= _maxRetries;

  String _formatDateTimeForMessage(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}";
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _run();
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

      // 1) Save profile – backend regenerates diet in background
      final response = await ProfileApi.updateProfile(
        widget.profilePayload,
      ).timeout(_timeout);
      if (!mounted) return;
      await AccountStorage.clearProfileEditBlockedUntil();

      await DietTargetsStorage.clearTargets();

      final dietPending =
          response['diet_pending'] == true ||
          response['diet_needs_regeneration'] == true;

      if (dietPending) {
        // 2) Poll until targets are fresh (stale == false)
        await _pollUntilFresh(userId);
      } else {
        // No diet regeneration needed – just fetch latest targets
        try {
          await DietService.fetchCurrentTargets(
            userId,
          ).timeout(const Duration(seconds: 15));
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
        final ok = await _tryFinishIfTargetsReady(userId);
        if (ok) return;
      }

      if (!mounted) return;

      final msg = userFriendlyErrorMessage(e);
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

  Future<void> _pollUntilFresh(int userId) async {
    final deadline = DateTime.now().add(_pollTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!mounted) return;
      await Future.delayed(_pollInterval);
      if (!mounted) return;
      try {
        final targets = await DietService.fetchCurrentTargets(
          userId,
        ).timeout(const Duration(seconds: 10));
        final stale = targets['stale'] == true;
        if (!stale) return;
      } catch (_) {
        // Keep polling on transient errors
      }
    }
  }

  Future<bool> _tryFinishIfTargetsReady(int userId) async {
    try {
      await DietService.fetchCurrentTargets(
        userId,
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return false;
      Navigator.of(context).pop(true);
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
                    _GenerationIcon(showError: _showFinalError),
                    SizedBox(height: TaqaUiScale.h(16)),
                    _GenerationText(
                      title: t.translate("updating_diet_title"),
                      body: t.translate("updating_diet_body"),
                    ),
                    SizedBox(height: TaqaUiScale.h(12)),
                    if (_isWorking) ...[
                      const TrainingLoadingIndicator(),
                      SizedBox(height: TaqaUiScale.h(12)),
                      if (!_showFinalError)
                        Text(
                          t.translate("generating_waiting_hint"),
                          style: _generationTextStyle(
                            11,
                            TaqaUiColors.unnamedColor1c1d17.withValues(
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
                        style: _generationTextStyle(
                          13,
                          TaqaUiColors.unnamedColorE93b3b,
                          weight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_cooldownBlocked && _cooldownUntil != null) ...[
                        SizedBox(height: TaqaUiScale.h(6)),
                        Text(
                          "Profile updates are limited to once each 30 days.",
                          textAlign: TextAlign.center,
                          style: _generationTextStyle(
                            12,
                            TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.7,
                            ),
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                      SizedBox(height: TaqaUiScale.h(6)),
                      Text(
                        _error ?? '',
                        textAlign: TextAlign.center,
                        style: _generationTextStyle(
                          11,
                          TaqaUiColors.unnamedColorE93b3b.withValues(
                            alpha: 0.9,
                          ),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(16)),
                      _UpdatingDietActionButton(
                        label: _cooldownBlocked
                            ? "Back"
                            : t.translate("generating_retry"),
                        onTap: _cooldownBlocked ? _goBack : _retry,
                      ),
                    ],
                    if (!_cooldownBlocked) ...[
                      SizedBox(height: TaqaUiScale.h(16)),
                      _GenerationNote(text: t.translate("updating_diet_note")),
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

  void _retry() {
    _retryCount = 0;
    _run();
  }

  void _goBack() {
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
  }
}

TextStyle _generationTextStyle(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: TaqaUiFontFamilies.interTight,
  fontSize: TaqaUiScale.sp(size),
  fontWeight: weight,
  color: color,
);

class _GenerationIcon extends StatelessWidget {
  const _GenerationIcon({required this.showError});
  final bool showError;
  @override
  Widget build(BuildContext context) => Container(
    padding: TaqaUiScale.insetsLTRB(10, 10, 10, 10),
    decoration: BoxDecoration(
      color: showError
          ? TaqaUiColors.unnamedColorE93b3b.withValues(alpha: 0.12)
          : TaqaUiColors.unnamedColorE4e93b,
      shape: BoxShape.circle,
    ),
    child: Icon(
      showError ? Icons.error_outline : Icons.auto_awesome,
      color: showError
          ? TaqaUiColors.unnamedColorE93b3b
          : TaqaUiColors.unnamedColor1c1d17,
      size: TaqaUiScale.w(22),
    ),
  );
}

class _GenerationText extends StatelessWidget {
  const _GenerationText({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: _generationTextStyle(
          17,
          TaqaUiColors.unnamedColor1c1d17,
          weight: FontWeight.w700,
        ),
      ),
      SizedBox(height: TaqaUiScale.h(8)),
      Text(
        body,
        textAlign: TextAlign.center,
        style: _generationTextStyle(
          13,
          TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
        ),
      ),
    ],
  );
}

class _GenerationNote extends StatelessWidget {
  const _GenerationNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
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
            text,
            style: _generationTextStyle(12, TaqaUiColors.unnamedColor1c1d17),
          ),
        ),
      ],
    ),
  );
}

class _UpdatingDietActionButton extends StatelessWidget {
  const _UpdatingDietActionButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: TaqaUiColors.unnamedColorE4e93b,
    borderRadius: TaqaUiScale.radius(12),
    child: InkWell(
      borderRadius: TaqaUiScale.radius(12),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: TaqaUiScale.h(46),
        child: Center(
          child: Text(
            label,
            style: _generationTextStyle(
              14,
              TaqaUiColors.unnamedColor1c1d17,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}
