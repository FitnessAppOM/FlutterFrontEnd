import 'package:flutter/material.dart';

import '../../widgets/dashboard/bar_trend.dart';
import '../styles/taqa_ui_scale.dart';

class TaqaDashboardTrendTile extends StatelessWidget {
  const TaqaDashboardTrendTile({
    super.key,
    required this.title,
    required this.data,
    required this.loading,
    required this.accentColor,
    required this.emptyLabel,
    this.onTap,
  });

  final String title;
  final List<double> data;
  final bool loading;
  final Color accentColor;
  final String emptyLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? Center(
            child: SizedBox(
              height: TaqaUiScale.h(28),
              width: TaqaUiScale.w(28),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : data.isEmpty
        ? Text(
            emptyLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          )
        : BarTrend(title: title, data: data, accentColor: accentColor);

    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
