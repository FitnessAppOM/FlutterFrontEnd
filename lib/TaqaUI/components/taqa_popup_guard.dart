import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as material;

/// Prevents rapid taps from pushing more than one Taqa popup route onto the
/// same navigator.
///
/// A duplicate invocation returns `null` (or completes immediately for void
/// popups). It deliberately does not share the active popup's result, because
/// that would make every duplicate caller process the same confirmation.
class TaqaPopupGuard {
  TaqaPopupGuard._();

  static final Set<NavigatorState> _activeNavigators = <NavigatorState>{};

  static Future<T?> open<T>({
    required BuildContext context,
    required Future<T?> Function() show,
    bool useRootNavigator = true,
  }) async {
    final navigator = Navigator.maybeOf(
      context,
      rootNavigator: useRootNavigator,
    );
    if (navigator == null) return show();
    if (!_activeNavigators.add(navigator)) return null;

    try {
      return await show();
    } finally {
      _activeNavigators.remove(navigator);
    }
  }

  static Future<void> openVoid({
    required BuildContext context,
    required Future<void> Function() show,
    bool useRootNavigator = true,
  }) async {
    final navigator = Navigator.maybeOf(
      context,
      rootNavigator: useRootNavigator,
    );
    if (navigator == null) {
      await show();
      return;
    }
    if (!_activeNavigators.add(navigator)) return;

    try {
      await show();
    } finally {
      _activeNavigators.remove(navigator);
    }
  }

  static Future<T?> dialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    material.Color? barrierColor,
  }) {
    return open<T>(
      context: context,
      show: () => material.showDialog<T>(
        context: context,
        barrierColor: barrierColor,
        builder: builder,
      ),
    );
  }

  static Future<void> dialogVoid({
    required BuildContext context,
    required WidgetBuilder builder,
    material.Color? barrierColor,
  }) {
    return openVoid(
      context: context,
      show: () => material.showDialog<void>(
        context: context,
        barrierColor: barrierColor,
        builder: builder,
      ),
    );
  }

  static Future<T?> bottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    material.Color? backgroundColor,
    material.Color? barrierColor,
  }) {
    return open<T>(
      context: context,
      useRootNavigator: false,
      show: () => material.showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        barrierColor: barrierColor,
        builder: builder,
      ),
    );
  }

  static Future<void> bottomSheetVoid({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    material.Color? backgroundColor,
    material.Color? barrierColor,
  }) {
    return openVoid(
      context: context,
      useRootNavigator: false,
      show: () => material.showModalBottomSheet<void>(
        context: context,
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        barrierColor: barrierColor,
        builder: builder,
      ),
    );
  }

  static Future<void> generalDialogVoid({
    required BuildContext context,
    required material.RoutePageBuilder pageBuilder,
    required String barrierLabel,
    bool barrierDismissible = false,
    material.Color barrierColor = const material.Color(0x80000000),
  }) {
    return openVoid(
      context: context,
      show: () => material.showGeneralDialog<void>(
        context: context,
        pageBuilder: pageBuilder,
        barrierLabel: barrierLabel,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
      ),
    );
  }
}
