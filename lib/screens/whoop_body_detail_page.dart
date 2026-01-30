import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/whoop_profile_service.dart';

class WhoopBodyDetailPage extends StatefulWidget {
  const WhoopBodyDetailPage({super.key});

  @override
  State<WhoopBodyDetailPage> createState() => _WhoopBodyDetailPageState();
}

class _WhoopBodyDetailPageState extends State<WhoopBodyDetailPage> {
  bool _loading = true;
  WhoopBodyMetrics? _metrics;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final metrics = await WhoopProfileService().fetchBodyMetrics();
      if (!mounted) return;
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
        title: const Text("Body insights"),
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
                : Column(
                    children: [
                      _metricCard(
                        title: "Height",
                        value: _fmtMeters(metrics.heightMeters),
                        icon: Icons.height,
                        accent: const Color(0xFF2D7CFF),
                      ),
                      const SizedBox(height: 12),
                      _metricCard(
                        title: "Weight",
                        value: _fmtKg(metrics.weightKg),
                        icon: Icons.monitor_weight,
                        accent: const Color(0xFF00BFA6),
                      ),
                      const SizedBox(height: 12),
                      _metricCard(
                        title: "Max HR",
                        value: _fmtBpm(metrics.maxHr),
                        icon: Icons.favorite,
                        accent: const Color(0xFFFF8A00),
                      ),
                    ],
                  ),
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
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.18)),
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
              "No body measurements yet",
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

  String _fmtKg(double? v) {
    if (v == null) return "—";
    return "${v.toStringAsFixed(1)} kg";
  }

  String _fmtBpm(int? v) {
    if (v == null) return "—";
    return "$v bpm";
  }
}
