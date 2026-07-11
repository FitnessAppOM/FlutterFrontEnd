import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/account_storage.dart';
import '../../services/share/cardio_share_service.dart';
import '../../services/strava/strava_service.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../widgets/cardio/cardio_exercise_utils.dart';

import '../../widgets/cardio/cardio_map.dart';
import '../../widgets/cardio/cardio_route_utils.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import 'other_models/other_models_page.dart';

class CardioAchievementSheet extends StatefulWidget {
  const CardioAchievementSheet({
    super.key,
    required this.durationSeconds,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.steps,
    required this.route,
    required this.exerciseName,
    this.userName,
    this.snapshotUrl,
    this.sessionDate,
    this.inclinePercent,
  });

  final int durationSeconds;
  final double distanceKm;
  final double avgSpeedKmh;
  final int steps;
  final List<CardioPoint> route;
  final String exerciseName;
  final String? userName;
  final String? snapshotUrl;
  final DateTime? sessionDate;
  final double? inclinePercent;

  @override
  State<CardioAchievementSheet> createState() => _CardioAchievementSheetState();
}

class _CardioAchievementSheetState extends State<CardioAchievementSheet> {
  final GlobalKey _captureKey = GlobalKey();
  final StravaService _stravaService = StravaService();
  bool _saving = false;
  bool _snapshotReady = false;
  bool _sharing = false;
  bool _hideMapForCapture = false;
  bool _stravaLinked = false;
  bool _stravaUploading = false;

  @override
  void initState() {
    super.initState();
    _loadStravaLinked();
  }

  Future<void> _loadStravaLinked() async {
    final cached = await AccountStorage.getStravaLinked();
    if (cached != null && mounted) {
      setState(() => _stravaLinked = cached);
    }
    try {
      final status = await _stravaService.fetchStatus();
      final linked = status["linked"] == true;
      if (!mounted) return;
      setState(() => _stravaLinked = linked);
      unawaited(AccountStorage.setStravaLinked(linked));
    } catch (_) {
      // Keep cached value if status request fails.
    }
  }

  String _formatTime(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return "$mm:$ss";
  }

  String _avgPaceLabel() {
    if (widget.durationSeconds <= 0) return "--:-- /km";
    if (widget.distanceKm <= 0.001) return "--:-- /km";
    final paceMin = (widget.durationSeconds / 60.0) / widget.distanceKm;
    final paceMinutes = paceMin.floor();
    final paceSeconds = ((paceMin - paceMinutes) * 60).round().clamp(0, 59);
    return "${paceMinutes.toString().padLeft(2, '0')}:${paceSeconds.toString().padLeft(2, '0')} /km";
  }

  String _buildSnapshotUrl() {
    if (widget.snapshotUrl != null && widget.snapshotUrl!.trim().isNotEmpty) {
      return widget.snapshotUrl!;
    }
    final token = dotenv.maybeGet('MAPBOX_PUBLIC_KEY') ?? '';
    return buildCardioSnapshotUrlMaster(token: token, route: widget.route);
  }

  String _sessionDateLabel() {
    final dt = (widget.sessionDate ?? DateTime.now()).toLocal();
    return dt.toString().split(' ').first;
  }

  bool get _showDistance => !isIndoorCardioExerciseName(widget.exerciseName);

  bool get _isMapless => isIndoorCardioExerciseName(widget.exerciseName);

  String? get _elevationLabel {
    final incline = widget.inclinePercent;
    if (incline == null || incline <= 0) return null;
    return '${incline.toStringAsFixed(1)}%';
  }

  Future<void> _saveScreenshot() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _ensureSnapshotPainted();
      final ok = await CardioShareService.ensurePhotoPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo permission denied')),
          );
        }
        return;
      }
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final output = await _buildExportBytes(boundary);
      if (output == null) return;
      await CardioShareService.savePngBytes(output);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to Photos')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List?> _capturePng(RenderRepaintBoundary boundary) {
    return CardioShareService.capturePng(boundary);
  }

  Future<Uint8List?> _buildExportBytes(RenderRepaintBoundary boundary) async {
    final bytes = await _capturePngWithOptionalHideMap(boundary);
    if (bytes == null) return null;
    final flattened = await CardioShareService.flattenPngOnBackground(
      bytes,
      TaqaUiColors.white,
      // Must match the captured card's own borderRadius (TaqaUiScale.radius(15)
      // in build()) so the background mask lines up with the card's actual
      // rounded corner instead of leaving square edges outside it.
      cornerRadius: TaqaUiScale.r(15),
    );
    return flattened ?? bytes;
  }

  Future<Uint8List?> _capturePngWithOptionalHideMap(
    RenderRepaintBoundary boundary,
  ) async {
    final snapshotUrl = _buildSnapshotUrl();
    final shouldHideMap = snapshotUrl.isEmpty;
    if (!shouldHideMap) {
      return _capturePng(boundary);
    }
    if (mounted) {
      setState(() => _hideMapForCapture = true);
    }
    await _nextFrame();
    final bytes = await _capturePng(boundary);
    if (mounted) {
      setState(() => _hideMapForCapture = false);
    }
    return bytes;
  }

  Future<void> _nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  Future<void> _ensureSnapshotPainted() async {
    if (!_snapshotReady) {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!_snapshotReady && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    await _nextFrame();
  }

  Future<void> _shareScreenshot() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await _ensureSnapshotPainted();
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final output = await _buildExportBytes(boundary);
      if (output == null) return;
      if (!mounted) return;
      await CardioShareService.sharePngBytes(context, output);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _friendlyStravaError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains("activity:write_permission") ||
        lower.contains("activity:write")) {
      return "Strava write permission is missing. Disconnect and reconnect Strava, then try again.";
    }
    if (lower.contains("strava request failed (401)")) {
      return "Strava authorization failed. Reconnect Strava and try again.";
    }
    return "Failed to upload activity to Strava.";
  }

  void _showGlobalToast(
    String message, {
    AppToastType type = AppToastType.info,
  }) {
    if (!mounted) return;
    AppToast.show(
      context,
      message,
      type: type,
      position: AppToastPosition.top,
      rootOverlay: true,
    );
  }

  Future<void> _uploadToStrava() async {
    if (_stravaUploading) return;
    setState(() => _stravaUploading = true);
    try {
      final sessionDate = (widget.sessionDate ?? DateTime.now()).toLocal();
      final elapsed = widget.durationSeconds > 0 ? widget.durationSeconds : 1;
      final distanceMeters = widget.distanceKm > 0
          ? widget.distanceKm * 1000.0
          : null;
      final name = "TAQA Cardio ${_sessionDateLabel()}";
      final descriptionParts = <String>[
        "Duration ${_formatTime(widget.durationSeconds)}",
        if (_showDistance)
          "Distance ${widget.distanceKm.toStringAsFixed(2)} km",
        "Pace ${_avgPaceLabel()}",
        "Steps ${widget.steps}",
      ];
      final description = descriptionParts.join(" • ");

      await _stravaService.createActivity(
        name: name,
        type: "Run",
        startDateLocal: StravaService.formatLocalForStrava(sessionDate),
        elapsedTimeSeconds: elapsed,
        description: description,
        distanceMeters: distanceMeters,
      );
      AccountStorage.notifyStravaChanged();

      if (!mounted) return;
      _showGlobalToast("Uploaded to Strava.", type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      _showGlobalToast(
        _friendlyStravaError(e.toString()),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _stravaUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshotUrl = _buildSnapshotUrl();
    if (snapshotUrl.isEmpty && !_snapshotReady) {
      _snapshotReady = true;
    }

    final actionTextStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(13),
      fontWeight: FontWeight.w600,
      color: TaqaUiColors.unnamedColor1c1d17,
    );

    return SafeArea(
      bottom: false,
      child: Container(
        padding: TaqaUiScale.insetsLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TaqaUiScale.r(20)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: TaqaUiScale.w(34),
              height: TaqaUiScale.h(4),
              margin: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
              decoration: BoxDecoration(
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.12),
                borderRadius: TaqaUiScale.radius(99),
              ),
            ),
            ClipRRect(
              borderRadius: TaqaUiScale.radius(18),
              child: Container(
                color: TaqaUiColors.unnamedColorE3e3e3,
                padding: TaqaUiScale.insetsLTRB(4, 4, 4, 4),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: Container(
                    padding: TaqaUiScale.insetsLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.white,
                      borderRadius: TaqaUiScale.radius(15),
                      border: Border.all(
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: TaqaUiScale.w(36),
                              height: TaqaUiScale.h(36),
                              child: Image.asset(
                                'lib/TaqaUI/Assets/Taqa_Fitness_Favicon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(9)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Taqa Fitness',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(14),
                                      color: TaqaUiColors.unnamedColor1c1d17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    widget.userName != null &&
                                            widget.userName!.trim().isNotEmpty
                                        ? widget.userName!
                                        : 'Cardio Achievement',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(11),
                                      color: TaqaUiColors.unnamedColor1c1d17
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: TaqaUiScale.insetsLTRB(8, 5, 8, 5),
                              decoration: BoxDecoration(
                                borderRadius: TaqaUiScale.radius(999),
                                border: Border.all(
                                  color: TaqaUiColors.unnamedColor1c1d17
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                _sessionDateLabel(),
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                  fontSize: TaqaUiScale.sp(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isMapless)
                          SizedBox(height: TaqaUiScale.h(30))
                        else if (!_hideMapForCapture) ...[
                          SizedBox(height: TaqaUiScale.h(12)),
                          ClipRRect(
                            borderRadius: TaqaUiScale.radius(14),
                            child: SizedBox(
                              height: TaqaUiScale.h(190),
                              child: snapshotUrl.isEmpty
                                  ? Container(
                                      color: TaqaUiColors.unnamedColorE3e3e3,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Route unavailable',
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          color: TaqaUiColors.unnamedColor1c1d17
                                              .withValues(alpha: 0.6),
                                          fontSize: TaqaUiScale.sp(13),
                                        ),
                                      ),
                                    )
                                  : ClipRect(
                                      child: Transform.scale(
                                        scale: 1.5,
                                        child: Image.network(
                                          snapshotUrl,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null) {
                                                  if (!_snapshotReady) {
                                                    WidgetsBinding.instance
                                                        .addPostFrameCallback((
                                                          _,
                                                        ) {
                                                          if (mounted) {
                                                            setState(
                                                              () =>
                                                                  _snapshotReady =
                                                                      true,
                                                            );
                                                          }
                                                        });
                                                  }
                                                  return child;
                                                }
                                                return Container(
                                                  color: TaqaUiColors
                                                      .unnamedColorE3e3e3,
                                                  alignment: Alignment.center,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: TaqaUiColors
                                                            .unnamedColor1c1d17,
                                                      ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(12)),
                        ],
                        if (!_isMapless && _hideMapForCapture)
                          SizedBox(height: TaqaUiScale.h(6)),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricChip(
                                label: 'Time',
                                value: _formatTime(widget.durationSeconds),
                              ),
                            ),
                            if (_showDistance)
                              SizedBox(width: TaqaUiScale.w(8)),
                            if (_showDistance)
                              Expanded(
                                child: _MetricChip(
                                  label: 'Distance',
                                  value:
                                      '${widget.distanceKm.toStringAsFixed(2)} km',
                                ),
                              ),
                            SizedBox(width: TaqaUiScale.w(8)),
                            Expanded(
                              child: _MetricChip(
                                label: 'Pace',
                                value: _avgPaceLabel(),
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(8)),
                            Expanded(
                              child: _MetricChip(
                                label: 'Steps',
                                value: '${widget.steps}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            SizedBox(
              width: double.infinity,
              height: TaqaUiScale.h(45),
              child: ElevatedButton(
                onPressed: (_saving || !_snapshotReady)
                    ? null
                    : _saveScreenshot,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: TaqaUiColors.lime,
                  disabledBackgroundColor: TaqaUiColors.lime.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: TaqaUiScale.radius(5),
                  ),
                ),
                child: Text(
                  _saving
                      ? 'Saving...'
                      : _snapshotReady
                      ? 'Save to Photos'
                      : 'Preparing...',
                  style: actionTextStyle,
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(8)),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: TaqaUiScale.h(45),
                    child: OutlinedButton(
                      onPressed: (_sharing || !_snapshotReady)
                          ? null
                          : _shareScreenshot,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                        side: BorderSide(
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: TaqaUiScale.radius(5),
                        ),
                      ),
                      child: Text(
                        _sharing
                            ? 'Sharing...'
                            : _snapshotReady
                            ? 'Share'
                            : 'Preparing...',
                        style: actionTextStyle,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(8)),
                Expanded(
                  child: SizedBox(
                    height: TaqaUiScale.h(45),
                    child: OutlinedButton(
                      onPressed: _snapshotReady
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OtherModelsPage(
                                    snapshotUrl: snapshotUrl,
                                    route: widget.route,
                                    durationLabel: _formatTime(
                                      widget.durationSeconds,
                                    ),
                                    showDistance: _showDistance,
                                    distanceLabel:
                                        "${widget.distanceKm.toStringAsFixed(2)} km",
                                    paceLabel: _avgPaceLabel(),
                                    userName: widget.userName,
                                    dateLabel: _sessionDateLabel(),
                                    isMapless: _isMapless,
                                    elevationLabel: _elevationLabel,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TaqaUiColors.unnamedColor1c1d17,
                        side: BorderSide(
                          color: TaqaUiColors.unnamedColor1c1d17.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: TaqaUiScale.radius(5),
                        ),
                      ),
                      child: Text('Other models', style: actionTextStyle),
                    ),
                  ),
                ),
              ],
            ),
            if (_stravaLinked) ...[
              SizedBox(height: TaqaUiScale.h(8)),
              SizedBox(
                width: double.infinity,
                height: TaqaUiScale.h(45),
                child: OutlinedButton.icon(
                  onPressed: _stravaUploading ? null : _uploadToStrava,
                  icon: Icon(Icons.upload, size: TaqaUiScale.w(16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFC4C02),
                    side: const BorderSide(color: Color(0xFFFC4C02)),
                    shape: RoundedRectangleBorder(
                      borderRadius: TaqaUiScale.radius(5),
                    ),
                  ),
                  label: Text(
                    _stravaUploading
                        ? 'Uploading to Strava...'
                        : 'Upload to Strava',
                    style: actionTextStyle.copyWith(
                      color: const Color(0xFFFC4C02),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: TaqaUiScale.h(8)),
            SizedBox(
              width: double.infinity,
              height: TaqaUiScale.h(36),
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('Cancel', style: actionTextStyle),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(4)),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TaqaUiScale.insetsLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: TaqaUiColors.unnamedColorE3e3e3,
        borderRadius: TaqaUiScale.radius(12),
        border: Border.all(
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.6),
                fontSize: TaqaUiScale.sp(9),
                letterSpacing: 0.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(height: TaqaUiScale.h(3)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: TaqaUiColors.unnamedColor1c1d17,
                fontSize: TaqaUiScale.sp(13),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
