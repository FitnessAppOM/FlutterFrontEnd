import 'package:flutter/material.dart';
import '../core/account_storage.dart';
import '../theme/app_theme.dart';
import '../localization/app_localizations.dart';
import '../services/whoop/whoop_profile_service.dart';

class WhoopBodyDetailPage extends StatefulWidget {
  const WhoopBodyDetailPage({super.key});

  @override
  State<WhoopBodyDetailPage> createState() => _WhoopBodyDetailPageState();
}

class _WhoopBodyDetailPageState extends State<WhoopBodyDetailPage> {
  bool _loading = true;
  WhoopBodyMetrics? _metrics;
  static final Map<int, WhoopBodyMetrics?> _cachedMetricsByUser = {};
  static final Set<int> _loadedUsers = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = await AccountStorage.getUserId();
    if (userId != null && _loadedUsers.contains(userId)) {
      setState(() {
        _metrics = _cachedMetricsByUser[userId];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final metrics = await WhoopProfileService().fetchBodyMetrics();
      if (!mounted) return;
      if (userId != null) {
        _cachedMetricsByUser[userId] = metrics;
        _loadedUsers.add(userId);
      }
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate("whoop_body_insights_title")),
        backgroundColor: AppColors.black,
      ),
      backgroundColor: AppColors.black,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : (metrics == null || !_hasAny(metrics))
            ? _emptyCard()
            : Builder(builder: (context) {
                final t = AppLocalizations.of(context).translate;
                return Column(
                  children: [
                    _metricCard(
                      title: t("body_height_label"),
                      value: _fmtMeters(metrics.heightMeters),
                      icon: Icons.height,
                      accent: const Color(0xFF2D7CFF),
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      title: t("body_weight_label"),
                      value: _fmtKg(metrics.weightKg, t("unit_kg")),
                      icon: Icons.monitor_weight,
                      accent: const Color(0xFF00BFA6),
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      title: t("whoop_max_hr_label"),
                      value: _fmtBpm(metrics.maxHr),
                      icon: Icons.favorite,
                      accent: const Color(0xFFFF8A00),
                    ),
                  ],
                );
              }),
      ),
    );
  }

  bool _hasAny(WhoopBodyMetrics metrics) {
    return metrics.heightMeters != null ||
        metrics.weightKg != null ||
        metrics.maxHr != null;
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2D7CFF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline, color: Color(0xFF2D7CFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate("whoop_no_body_measurements"),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtMeters(double? v) {
    if (v == null) return "—";
    return "${v.toStringAsFixed(2)} m";
  }

  String _fmtKg(double? v, String unit) {
    if (v == null) return "—";
    return "${v.toStringAsFixed(1)} $unit";
  }

  String _fmtBpm(int? v) {
    if (v == null) return "—";
    return "$v bpm";
  }
}
