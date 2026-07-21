import 'dart:async';
import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../services/diet/diet_service.dart';
import '../services/diet/diet_targets_storage.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../widgets/taqa_bolt_loading_screen.dart';
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

    if (_isWorking) {
      return PopScope(
        canPop: _cooldownBlocked,
        child: Scaffold(
          backgroundColor: TaqaBoltLoadingScreen.background,
          body: TaqaBoltLoadingScreen(
            note: t.translate("updating_diet_note"),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _cooldownBlocked,
      child: Scaffold(
        backgroundColor: TaqaBoltLoadingScreen.background,
        body: TaqaBoltStatusScreen(
          title: t.translate("updating_diet_title"),
          body: t.translate("updating_diet_body"),
          showError: _showFinalError,
          errorHeadline: _cooldownBlocked
              ? t.translate("profile_edit_locked_title")
              : t.translate("generating_error_title"),
          cooldownNote: _cooldownBlocked && _cooldownUntil != null
              ? t.translate("profile_edit_locked_note")
              : null,
          errorDetail: _error,
          buttonLabel: _showFinalError
              ? (_cooldownBlocked
                    ? t.translate("back")
                    : t.translate("generating_retry"))
              : null,
          onButtonTap: _cooldownBlocked ? _goBack : _retry,
          note: _cooldownBlocked ? null : t.translate("updating_diet_note"),
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

