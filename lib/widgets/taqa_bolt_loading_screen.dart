import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../localization/app_localizations.dart';

/// Full-screen "charging bolt" loading state shown while Taqa generates or
/// regenerates a plan (training, diet, or a combined update). Used after
/// sign-up questionnaire completion and after profile edits that trigger
/// regeneration.
class TaqaBoltLoadingScreen extends StatefulWidget {
  const TaqaBoltLoadingScreen({super.key, required this.note});

  final String note;

  static const Color background = Color(0xFF050505);

  @override
  State<TaqaBoltLoadingScreen> createState() => _TaqaBoltLoadingScreenState();
}

class _TaqaBoltLoadingScreenState extends State<TaqaBoltLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final captionTemplate = t.translate("bolt_loading_caption");
    final captionParts = captionTemplate.split("{taqa}");
    final captionPrefix = captionParts.first;
    final captionSuffix = captionParts.length > 1 ? captionParts[1] : "";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: TaqaBoltLoadingScreen.background,
        padding: TaqaUiScale.insetsLTRB(24, 40, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(19),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF2F2F2),
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(text: captionPrefix),
                      TextSpan(
                        text: t.translate("bolt_loading_taqa_word"),
                        style: const TextStyle(color: Color(0xFFE4E93B)),
                      ),
                      TextSpan(text: captionSuffix),
                    ],
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(28)),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth * 0.6;
                    return SizedBox(
                      width: w,
                      child: AspectRatio(
                        aspectRatio: 749 / 1012,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, _) => CustomPaint(
                            painter: _BoltPainter(_controller.value),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: TaqaUiScale.h(16)),
                Text(
                  t.translate("generating_waiting_hint"),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(11),
                    color: const Color(0xFFF2F2F2).withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(10)),
                Text(
                  widget.note,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(12),
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFF2F2F2).withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dark-themed status/error card shown alongside [TaqaBoltLoadingScreen] for
/// the non-loading states of plan generation: the retry-pending pause, the
/// final error after retries are exhausted, and the profile-edit cooldown
/// lockout. Keeps the same dark backdrop so the whole flow reads as one
/// continuous screen instead of flashing back to a light card.
class TaqaBoltStatusScreen extends StatelessWidget {
  const TaqaBoltStatusScreen({
    super.key,
    required this.title,
    required this.body,
    this.showError = false,
    this.errorHeadline,
    this.cooldownNote,
    this.errorDetail,
    this.buttonLabel,
    this.onButtonTap,
    this.note,
  });

  final String title;
  final String body;
  final bool showError;
  final String? errorHeadline;
  final String? cooldownNote;
  final String? errorDetail;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final String? note;

  static const Color _errorRed = Color(0xFFE93B3B);
  static const Color _lime = Color(0xFFE4E93B);
  static const Color _ink = Color(0xFF1C1D17);
  static const Color _offWhite = Color(0xFFF2F2F2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: TaqaBoltLoadingScreen.background,
      padding: TaqaUiScale.insetsLTRB(24, 40, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: TaqaUiScale.insetsLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: showError
                      ? _errorRed.withValues(alpha: 0.15)
                      : _lime.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  showError ? Icons.error_outline : Icons.auto_awesome,
                  color: showError ? _errorRed : _lime,
                  size: TaqaUiScale.w(24),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(18)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(18),
                  fontWeight: FontWeight.w700,
                  color: _offWhite,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(13),
                  fontWeight: FontWeight.w400,
                  color: _offWhite.withValues(alpha: 0.55),
                ),
              ),
              if (showError) ...[
                SizedBox(height: TaqaUiScale.h(20)),
                if (errorHeadline != null)
                  Text(
                    errorHeadline!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(14),
                      fontWeight: FontWeight.w700,
                      color: _errorRed,
                    ),
                  ),
                if (cooldownNote != null) ...[
                  SizedBox(height: TaqaUiScale.h(6)),
                  Text(
                    cooldownNote!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(12),
                      fontWeight: FontWeight.w600,
                      color: _offWhite.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                if (errorDetail != null && errorDetail!.isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(6)),
                  Text(
                    errorDetail!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(11),
                      color: _errorRed.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (buttonLabel != null) ...[
                  SizedBox(height: TaqaUiScale.h(20)),
                  Material(
                    color: _lime,
                    borderRadius: TaqaUiScale.radius(12),
                    child: InkWell(
                      borderRadius: TaqaUiScale.radius(12),
                      onTap: onButtonTap,
                      child: SizedBox(
                        width: double.infinity,
                        height: TaqaUiScale.h(48),
                        child: Center(
                          child: Text(
                            buttonLabel!,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(14),
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              if (note != null) ...[
                SizedBox(height: TaqaUiScale.h(20)),
                Container(
                  padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: TaqaUiScale.radius(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user,
                        color: _offWhite.withValues(alpha: 0.8),
                        size: TaqaUiScale.w(18),
                      ),
                      SizedBox(width: TaqaUiScale.w(10)),
                      Expanded(
                        child: Text(
                          note!,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(12),
                            fontWeight: FontWeight.w400,
                            color: _offWhite.withValues(alpha: 0.75),
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
    );
  }
}

class _BoltSegment {
  const _BoltSegment({
    required this.y,
    required this.h,
    required this.radius,
    required this.staticX,
    required this.staticW,
    required this.activeX,
    required this.activeW,
    required this.growStart,
    required this.growEnd,
  });

  final double y;
  final double h;
  final double radius;
  final double staticX;
  final double staticW;
  final double activeX;
  final double activeW;
  final double growStart;
  final double growEnd;

  static const double shrinkStart = 0.90;
  static const double shrinkEnd = 0.98;

  double progressAt(double t) {
    if (t < growStart) return 0;
    if (t < growEnd) {
      final f = ((t - growStart) / (growEnd - growStart)).clamp(0.0, 1.0);
      return Curves.easeOut.transform(f);
    }
    if (t < shrinkStart) return 1;
    if (t < shrinkEnd) {
      final f = ((t - shrinkStart) / (shrinkEnd - shrinkStart)).clamp(
        0.0,
        1.0,
      );
      return 1 - Curves.easeOut.transform(f);
    }
    return 0;
  }
}

const List<_BoltSegment> _boltSegments = [
  _BoltSegment(y: 984, h: 26, radius: 13.0, staticX: 188.5, staticW: 26, activeX: 181, activeW: 41, growStart: 0.00000, growEnd: 0.20000),
  _BoltSegment(y: 932, h: 27, radius: 13.5, staticX: 217.5, staticW: 27, activeX: 200, activeW: 62, growStart: 0.03158, growEnd: 0.23158),
  _BoltSegment(y: 881, h: 27, radius: 13.5, staticX: 247.0, staticW: 27, activeX: 218, activeW: 85, growStart: 0.06316, growEnd: 0.26316),
  _BoltSegment(y: 829, h: 27, radius: 13.5, staticX: 277.0, staticW: 27, activeX: 237, activeW: 107, growStart: 0.09474, growEnd: 0.29474),
  _BoltSegment(y: 778, h: 27, radius: 13.5, staticX: 306.0, staticW: 27, activeX: 255, activeW: 129, growStart: 0.12632, growEnd: 0.32632),
  _BoltSegment(y: 726, h: 27, radius: 13.5, staticX: 336.0, staticW: 27, activeX: 274, activeW: 151, growStart: 0.15789, growEnd: 0.35789),
  _BoltSegment(y: 674, h: 28, radius: 14.0, staticX: 365.0, staticW: 28, activeX: 292, activeW: 174, growStart: 0.18947, growEnd: 0.38947),
  _BoltSegment(y: 623, h: 27, radius: 13.5, staticX: 395.5, staticW: 27, activeX: 311, activeW: 196, growStart: 0.22105, growEnd: 0.42105),
  _BoltSegment(y: 571, h: 27, radius: 13.5, staticX: 296.5, staticW: 27, activeX: 73, activeW: 474, growStart: 0.25263, growEnd: 0.45263),
  _BoltSegment(y: 520, h: 27, radius: 13.5, staticX: 337.0, staticW: 27, activeX: 113, activeW: 475, growStart: 0.28421, growEnd: 0.48421),
  _BoltSegment(y: 468, h: 27, radius: 13.5, staticX: 378.0, staticW: 27, activeX: 154, activeW: 475, growStart: 0.31579, growEnd: 0.51579),
  _BoltSegment(y: 417, h: 27, radius: 13.5, staticX: 418.5, staticW: 27, activeX: 195, activeW: 474, growStart: 0.34737, growEnd: 0.54737),
  _BoltSegment(y: 365, h: 27, radius: 13.5, staticX: 319.5, staticW: 27, activeX: 235, activeW: 196, growStart: 0.37895, growEnd: 0.57895),
  _BoltSegment(y: 313, h: 28, radius: 14.0, staticX: 349.0, staticW: 28, activeX: 276, activeW: 174, growStart: 0.41053, growEnd: 0.61053),
  _BoltSegment(y: 262, h: 27, radius: 13.5, staticX: 379.0, staticW: 27, activeX: 317, activeW: 151, growStart: 0.44211, growEnd: 0.64211),
  _BoltSegment(y: 210, h: 27, radius: 13.5, staticX: 409.0, staticW: 27, activeX: 358, activeW: 129, growStart: 0.47368, growEnd: 0.67368),
  _BoltSegment(y: 159, h: 27, radius: 13.5, staticX: 438.0, staticW: 27, activeX: 398, activeW: 107, growStart: 0.50526, growEnd: 0.70526),
  _BoltSegment(y: 107, h: 27, radius: 13.5, staticX: 468.0, staticW: 27, activeX: 439, activeW: 85, growStart: 0.53684, growEnd: 0.73684),
  _BoltSegment(y: 56, h: 27, radius: 13.5, staticX: 498.0, staticW: 27, activeX: 480, activeW: 63, growStart: 0.56842, growEnd: 0.76842),
  _BoltSegment(y: 4, h: 27, radius: 13.5, staticX: 527.0, staticW: 27, activeX: 520, activeW: 41, growStart: 0.60000, growEnd: 0.80000),
];

class _BoltPainter extends CustomPainter {
  _BoltPainter(this.t);

  final double t;

  static const Color _gray = Color(0xFF3A3A3A);
  static const Color _lime = Color(0xFFE4E93B);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 749.0;
    final sy = size.height / 1012.0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final seg in _boltSegments) {
      final progress = seg.progressAt(t);
      final x = lerpDouble(seg.staticX, seg.activeX, progress)!;
      final w = lerpDouble(seg.staticW, seg.activeW, progress)!;
      final color = Color.lerp(_gray, _lime, progress)!;

      final rect = Rect.fromLTWH(x * sx, seg.y * sy, w * sx, seg.h * sy);
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(seg.radius * sx),
      );
      paint.color = color;
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) =>
      oldDelegate.t != t;
}
