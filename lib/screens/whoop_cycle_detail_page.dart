import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_pillar_card.dart';
import '../TaqaUI/components/taqa_score_widget.dart' show TaqaOpenArcPainter;
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/whoop/whoop_cycle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/charts/simple_line_chart.dart';

class WhoopCycleDetailPage extends StatefulWidget {
  const WhoopCycleDetailPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<WhoopCycleDetailPage> createState() => _WhoopCycleDetailPageState();
}

class _WhoopCycleDetailPageState extends State<WhoopCycleDetailPage> {
  static const int _previewYearsBack = 5;
  static const double _maxStrain = 21;

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
      final data = await WhoopCycleService().fetchDailyCycles(
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
    final metrics = _dailyCache[_selectedDate];
    final strain = _numFromAny(metrics?["strain"]);
    final hasData = strain != null;

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        title: AppLocalizations.of(
          context,
        ).translate("whoop_daily_cycle_title"),
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
                ..._buildDetailsSection(metrics!)
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
          final strain = _numFromAny(_dailyCache[day]?["strain"]);
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
                  _StrainPreviewCard(strain: strain),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDetailsSection(Map<String, dynamic> metrics) {
    final avgHr = _numFromAny(metrics["avg_hr"]);
    final maxHr = _numFromAny(metrics["max_hr"]);
    final kilojoules = _numFromAny(metrics["kilojoules"]);
    return [
      TaqaPillarCard(
        metricKey: 'avg_hr',
        label: AppLocalizations.of(context).translate("whoop_avg_hr_label"),
        score: avgHr,
        maxScore: 180,
        icon: Icons.favorite_rounded,
        color: const Color(0xFFE84C4F),
        details: const {},
        detailLabels: const {},
        valueDisplay: avgHr == null ? null : '${_fmt(avgHr)} bpm',
      ),
      SizedBox(height: TaqaUiScale.h(12)),
      TaqaPillarCard(
        metricKey: 'max_hr',
        label: AppLocalizations.of(context).translate("whoop_max_hr_label"),
        score: maxHr,
        maxScore: 200,
        icon: Icons.speed_rounded,
        color: const Color(0xFFFF8A00),
        details: const {},
        detailLabels: const {},
        valueDisplay: maxHr == null ? null : '${_fmt(maxHr)} bpm',
      ),
      SizedBox(height: TaqaUiScale.h(12)),
      TaqaPillarCard(
        metricKey: 'kilojoules',
        label: AppLocalizations.of(context).translate("whoop_energy_label"),
        score: kilojoules,
        maxScore: 20000,
        icon: Icons.bolt_rounded,
        color: const Color(0xFF35B6FF),
        details: const {},
        detailLabels: const {},
        valueDisplay: kilojoules == null ? null : '${_fmt(kilojoules)} kJ',
      ),
      SizedBox(height: TaqaUiScale.h(16)),
      Center(
        child: Text(
          AppLocalizations.of(context).translate("whoop_avg_hr_trend"),
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            color: TaqaUiColors.charcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      SizedBox(height: TaqaUiScale.h(8)),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SimpleLineChart(
            values: _avgHrSeries(),
            color: const Color(0xFFE84C4F),
            showPoints: true,
            labelColor: TaqaUiColors.charcoal.withValues(alpha: 0.5),
            titleColor: TaqaUiColors.charcoal.withValues(alpha: 0.5),
            gridColor: TaqaUiColors.charcoal,
            pointColor: TaqaUiColors.white,
          ),
        ),
      ),
      SizedBox(height: TaqaUiScale.h(10)),
      _avgHrNote(),
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
            AppLocalizations.of(context).translate("whoop_no_cycle_data"),
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

  List<double?> _avgHrSeries() {
    final start = _selectedDate.subtract(const Duration(days: 6));
    final values = <double?>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      values.add(_numFromAny(_dailyCache[d]?["avg_hr"]));
    }
    return values;
  }

  Widget _avgHrNote() {
    final yesterday = _selectedDate.subtract(const Duration(days: 1));
    final today = _dailyCache[_selectedDate]?["avg_hr"];
    final prev = _dailyCache[yesterday]?["avg_hr"];
    if (today is! num || prev is! num) {
      return const SizedBox.shrink();
    }
    final delta = today.toDouble() - prev.toDouble();
    final up = delta >= 0;
    final t = AppLocalizations.of(context).translate;
    final text = up
        ? t("whoop_avg_hr_up").replaceAll("{delta}", delta.toStringAsFixed(1))
        : t(
            "whoop_avg_hr_down",
          ).replaceAll("{delta}", delta.abs().toStringAsFixed(1));
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TaqaUiColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00))
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              up ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: up ? const Color(0xFF4CD964) : const Color(0xFFFF8A00),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _numFromAny(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _fmt(dynamic v) {
    if (v is num) {
      if (v == v.roundToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(1);
    }
    return "—";
  }
}

class _StrainPreviewCard extends StatelessWidget {
  const _StrainPreviewCard({this.strain});

  final double? strain;

  @override
  Widget build(BuildContext context) {
    final valueText = strain == null ? '0.0' : strain!.toStringAsFixed(1);
    final progress = strain == null
        ? 0.0
        : (strain! / _WhoopCycleDetailPageState._maxStrain).clamp(0.0, 1.0);

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
                          valueText,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(30),
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
