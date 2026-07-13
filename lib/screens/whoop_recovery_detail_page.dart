import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_linear_metric_card.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_score_widget.dart' show TaqaOpenArcPainter;
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/whoop/whoop_recovery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/simple_line_chart.dart';

class WhoopRecoveryDetailPage extends StatefulWidget {
  const WhoopRecoveryDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<WhoopRecoveryDetailPage> createState() =>
      _WhoopRecoveryDetailPageState();
}

class _WhoopRecoveryDetailPageState extends State<WhoopRecoveryDetailPage> {
  static const int _previewYearsBack = 5;

  late DateTime _selectedDate;
  late final PageController _previewController;
  static final Map<DateTime, Map<String, dynamic>> _dailyCache = {};
  static final Set<String> _loadedWindowKeys = <String>{};
  static int? _cacheUserId;
  final Set<String> _windowLoadingKeys = <String>{};
  bool _loading = true;
  int _reqId = 0;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _sameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

  DateTime _maxSelectableDate() => _dateOnly(DateTime.now());

  DateTime _previewStartDate() => _maxSelectableDate().subtract(
    const Duration(days: 365 * _previewYearsBack),
  );

  int _previewItemCount() =>
      _maxSelectableDate().difference(_previewStartDate()).inDays + 1;

  DateTime _previewDateForIndex(int index) {
    final safeIndex = index.clamp(0, _previewItemCount() - 1);
    return _previewStartDate().add(Duration(days: safeIndex));
  }

  int _previewIndexForDate(DateTime date) {
    final days = _dateOnly(date).difference(_previewStartDate()).inDays;
    return days.clamp(0, _previewItemCount() - 1);
  }

  @override
  void initState() {
    super.initState();
    final initial = _dateOnly(widget.initialDate ?? DateTime.now());
    _selectedDate = initial.isAfter(_maxSelectableDate())
        ? _maxSelectableDate()
        : initial;
    _previewController = PageController(
      initialPage: _previewIndexForDate(_selectedDate),
      viewportFraction: 186 / 358,
    );
    _ensureLoaded(_selectedDate);
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  String _windowKey(int? userId, DateTime end) =>
      "${userId ?? 0}|${end.toIso8601String()}";

  Future<void> _ensureLoaded(DateTime day) async {
    final reqId = ++_reqId;
    final userId = await AccountStorage.getUserId();
    if (_cacheUserId != userId) {
      _cacheUserId = userId;
      _dailyCache.clear();
      _loadedWindowKeys.clear();
    }
    final key = _windowKey(userId, day);
    if (_dailyCache.containsKey(day)) {
      if (mounted && reqId == _reqId) setState(() => _loading = false);
    } else if (!_windowLoadingKeys.contains(key)) {
      if (mounted) setState(() => _loading = true);
    }
    if (_loadedWindowKeys.contains(key) || _windowLoadingKeys.contains(key)) {
      return;
    }
    _windowLoadingKeys.add(key);
    try {
      final start = day.subtract(const Duration(days: 6));
      final data = await WhoopRecoveryService().fetchDailyRecovery(
        start: start,
        end: day,
      );
      _dailyCache.addAll(data);
      _loadedWindowKeys.add(key);
    } catch (_) {
      // Keep whatever is cached; missing days just render as no-data.
    } finally {
      _windowLoadingKeys.remove(key);
      if (mounted && reqId == _reqId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onPreviewPageChanged(int index) async {
    final day = _previewDateForIndex(index);
    if (_sameDay(day, _selectedDate)) return;
    setState(() => _selectedDate = day);
    await _ensureLoaded(day);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _currentMetrics(_dailyCache[_selectedDate]);
    final hasData = metrics.recoveryScore != null;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        title: AppLocalizations.of(context).translate("whoop_recovery_title"),
        backgroundColor: AppColors.appBackground,
        titleColor: TaqaUiColors.charcoal,
        leading: const BackButton(color: TaqaUiColors.charcoal),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.cardDark,
          onRefresh: () async {
            _loadedWindowKeys.remove(_windowKey(_cacheUserId, _selectedDate));
            await _ensureLoaded(_selectedDate);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildPreviewCarousel(),
              const SizedBox(height: 20),
              if (hasData)
                ..._buildDetailsSection(metrics)
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else
                _buildNoData(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCarousel() {
    final currentIndex = _previewIndexForDate(_selectedDate);
    final locale = Localizations.localeOf(context).languageCode == 'ar'
        ? 'ar'
        : 'en';

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _previewController,
        onPageChanged: (index) => _onPreviewPageChanged(index),
        itemCount: _previewItemCount(),
        itemBuilder: (context, index) {
          final day = _previewDateForIndex(index);
          final isCenter = index == currentIndex;
          final score = _numFromAny(_dailyCache[day]?["recovery_score"]);
          final label = DateFormat(
            'EEE, MMM d',
            locale,
          ).format(day).toUpperCase();
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              8,
              isCenter ? 2 : 14,
              8,
              isCenter ? 2 : 14,
            ),
            child: Opacity(
              opacity: isCenter ? 1 : 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: TaqaUiScale.w(62),
                    height: TaqaUiScale.h(10),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                        fontSize: TaqaUiScale.sp(8),
                        fontWeight: FontWeight.w400,
                        color: TaqaUiColors.charcoal,
                        height: 10 / 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RecoveryPreviewCard(score: score),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDetailsSection(_RecoveryMetrics metrics) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TaqaLinearMetricCard(
              title: AppLocalizations.of(
                context,
              ).translate("fitbit_heart_resting_hr"),
              valueText: metrics.rhr == null
                  ? '—'
                  : '${_fmt(metrics.rhr)} bpm',
              subtitle: AppLocalizations.of(
                context,
              ).translate("whoop_recovery_title"),
              progress: 0,
              showBar: false,
              keepBarSpaceWhenHidden: false,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(12)),
          Expanded(
            child: TaqaLinearMetricCard(
              title: AppLocalizations.of(
                context,
              ).translate("fitbit_heart_hrv_rmssd"),
              valueText: metrics.hrv == null
                  ? '—'
                  : '${_fmt(metrics.hrv)} ms',
              subtitle: AppLocalizations.of(
                context,
              ).translate("whoop_recovery_title"),
              progress: 0,
              showBar: false,
              keepBarSpaceWhenHidden: false,
            ),
          ),
        ],
      ),
      SizedBox(height: TaqaUiScale.h(12)),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TaqaLinearMetricCard(
              title: AppLocalizations.of(
                context,
              ).translate("whoop_spo2_level"),
              valueText: metrics.spo2 == null
                  ? '—'
                  : '${_fmt(metrics.spo2)}%',
              subtitle: AppLocalizations.of(
                context,
              ).translate("whoop_recovery_title"),
              progress: 0,
              showBar: false,
              keepBarSpaceWhenHidden: false,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(12)),
          Expanded(
            child: TaqaLinearMetricCard(
              title: AppLocalizations.of(
                context,
              ).translate("whoop_skin_temp"),
              valueText: metrics.skinTemp == null
                  ? '—'
                  : '${_fmt(metrics.skinTemp)}°C',
              subtitle: AppLocalizations.of(
                context,
              ).translate("whoop_recovery_title"),
              progress: 0,
              showBar: false,
              keepBarSpaceWhenHidden: false,
            ),
          ),
        ],
      ),
      SizedBox(height: TaqaUiScale.h(16)),
      Center(
        child: _sectionTitle(
          AppLocalizations.of(context).translate("whoop_recovery_trend"),
        ),
      ),
      SizedBox(height: TaqaUiScale.h(8)),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              SimpleLineChart(
                values: _recoverySeries(),
                color: TaqaUiColors.lime,
                showPoints: true,
                labelColor: TaqaUiColors.charcoal.withValues(alpha: 0.5),
                titleColor: TaqaUiColors.charcoal.withValues(alpha: 0.5),
                gridColor: TaqaUiColors.charcoal,
                pointColor: TaqaUiColors.white,
              ),
              SizedBox(height: TaqaUiScale.h(8)),
              _weekdayLabels(),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildNoData() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).translate("whoop_no_recovery_data"),
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<double?> _recoverySeries() {
    final start = _selectedDate.subtract(const Duration(days: 6));
    final values = <double?>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      values.add(_numFromAny(_dailyCache[d]?["recovery_score"]));
    }
    return values;
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        fontSize: TaqaUiScale.sp(15),
        color: TaqaUiColors.charcoal,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  _RecoveryMetrics _currentMetrics(Map<String, dynamic>? today) {
    return _RecoveryMetrics(
      recoveryScore: _numFromAny(today?["recovery_score"]),
      rhr: _numFromAny(today?["rhr"]),
      hrv: _numFromAny(today?["hrv"]),
      spo2: _numFromAny(today?["spo2"]),
      skinTemp: _numFromAny(today?["skin_temp_c"]),
    );
  }

  String _fmt(double? v) {
    if (v == null) return "—";
    return v.toStringAsFixed(1);
  }

  double? _numFromAny(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _weekdayLabels() {
    final start = _selectedDate.subtract(const Duration(days: 6));
    final labels = List.generate(
      7,
      (i) => _weekdayName(start.add(Duration(days: i)).weekday),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (l) => Text(
              l,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                fontSize: TaqaUiScale.sp(11),
              ),
            ),
          )
          .toList(),
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return "Mon";
      case DateTime.tuesday:
        return "Tue";
      case DateTime.wednesday:
        return "Wed";
      case DateTime.thursday:
        return "Thu";
      case DateTime.friday:
        return "Fri";
      case DateTime.saturday:
        return "Sat";
      case DateTime.sunday:
        return "Sun";
      default:
        return "";
    }
  }
}

class _RecoveryMetrics {
  const _RecoveryMetrics({
    required this.recoveryScore,
    required this.rhr,
    required this.hrv,
    required this.spo2,
    required this.skinTemp,
  });

  final double? recoveryScore;
  final double? rhr;
  final double? hrv;
  final double? spo2;
  final double? skinTemp;
}

class _RecoveryPreviewCard extends StatelessWidget {
  const _RecoveryPreviewCard({this.score});

  final double? score;

  @override
  Widget build(BuildContext context) {
    final value = score?.round() ?? 0;
    final progress = score == null ? 0.0 : (score! / 100).clamp(0.0, 1.0);

    final arcSize = TaqaUiScale.w(141);
    final visibleHeight = TaqaUiScale.h(124);

    return Container(
      width: TaqaUiScale.w(171),
      height: TaqaUiScale.h(171),
      decoration: BoxDecoration(
        color: TaqaUiColors.unnamedColorE4e93b,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Stack(
        children: [
          Positioned(
            left: TaqaUiScale.w(15),
            top: TaqaUiScale.h(27),
            width: arcSize,
            height: visibleHeight,
            child: ClipRect(
              child: OverflowBox(
                maxWidth: arcSize,
                maxHeight: arcSize,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: arcSize,
                  height: arcSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size.square(arcSize),
                        painter: TaqaOpenArcPainter(progress: progress),
                      ),
                      Transform.translate(
                        offset: Offset(0, -((arcSize - visibleHeight) / 2)),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(35),
                            fontWeight: FontWeight.w800,
                            color: TaqaUiColors.charcoal,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: TaqaUiScale.w(15),
            top: TaqaUiScale.h(132),
            width: TaqaUiScale.w(141),
            height: TaqaUiScale.h(10),
            child: Text(
              'WHOOP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(8),
                fontWeight: FontWeight.w400,
                color: TaqaUiColors.charcoal,
                height: 13 / 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
