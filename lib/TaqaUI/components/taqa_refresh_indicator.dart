import 'package:flutter/material.dart';

import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_toast.dart';

/// Pull-to-refresh wrapper matching the community page's design (charcoal
/// spinner on a white puck) plus a short cooldown so a user yanking the
/// pull-to-refresh gesture repeatedly can't hammer the backend — repeat
/// pulls within [cooldown] of the last completed refresh resolve instantly
/// instead of re-triggering [onRefresh].
///
/// `RefreshIndicator` already blocks a second pull while one is in flight
/// (the gesture stays locked until the returned future resolves); this only
/// covers the remaining gap of rapid pulls back-to-back *after* each one
/// finishes.
class TaqaRefreshIndicator extends StatefulWidget {
  const TaqaRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.cooldown = const Duration(seconds: 8),
    this.showCooldownToast = true,
    this.color = TaqaUiColors.charcoal,
    this.backgroundColor = TaqaUiColors.white,
    this.notificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// Minimum time between the end of one refresh and the start of the next
  /// actually hitting [onRefresh].
  final Duration cooldown;

  /// Whether to surface a toast when a pull is swallowed by the cooldown.
  final bool showCooldownToast;

  final Color color;
  final Color backgroundColor;

  /// Passed straight through to [RefreshIndicator.notificationPredicate]
  /// (e.g. only allow the pull gesture while viewing "today").
  final ScrollNotificationPredicate? notificationPredicate;

  @override
  State<TaqaRefreshIndicator> createState() => _TaqaRefreshIndicatorState();
}

class _TaqaRefreshIndicatorState extends State<TaqaRefreshIndicator> {
  DateTime? _lastRefreshAt;

  Future<void> _handleRefresh() async {
    final lastRefreshAt = _lastRefreshAt;
    if (lastRefreshAt != null &&
        DateTime.now().difference(lastRefreshAt) < widget.cooldown) {
      if (widget.showCooldownToast && mounted) {
        AppToast.show(
          context,
          "Already up to date",
          type: AppToastType.info,
        );
      }
      return;
    }
    await widget.onRefresh();
    _lastRefreshAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: widget.color,
      backgroundColor: widget.backgroundColor,
      strokeWidth: TaqaUiScale.w(2),
      notificationPredicate:
          widget.notificationPredicate ?? defaultScrollNotificationPredicate,
      onRefresh: _handleRefresh,
      // Without this, pulling to refresh also triggers Android's default
      // glowing overscroll indicator — a stray blue line/glow at the top of
      // the list, in the platform's default blue rather than any app color.
      child: ScrollConfiguration(
        behavior: const _NoGlowScrollBehavior(),
        child: widget.child,
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
