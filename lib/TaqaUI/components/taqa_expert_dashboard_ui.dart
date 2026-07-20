import 'package:flutter/material.dart';

import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';
import 'taqa_outline_tag_button.dart';

class TaqaDashboardPageHeader extends StatelessWidget {
  const TaqaDashboardPageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TaqaUiScale.h(39),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w700,
              height: 25 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.charcoal,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_forward_ios
                    : Icons.arrow_back_ios_new,
                size: TaqaUiScale.w(18),
                color: TaqaUiColors.charcoal,
              ),
            ),
          ),
          if (trailing != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing!),
        ],
      ),
    );
  }
}

class TaqaManagementSectionTitle extends StatelessWidget {
  const TaqaManagementSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            color: TaqaUiColors.charcoal,
            fontWeight: FontWeight.w700,
            fontSize: TaqaUiScale.sp(18),
          ),
        ),
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          SizedBox(height: TaqaUiScale.h(4)),
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 18 / 15,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class TaqaManagementMetricCard extends StatelessWidget {
  const TaqaManagementMetricCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TaqaUiScale.h(75),
      padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              color: TaqaUiColors.unnamedColor1c1d17,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              height: 10 / 8,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              color: TaqaUiColors.unnamedColor1c1d17,
              fontSize: TaqaUiScale.sp(25),
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaManagementTag extends StatelessWidget {
  const TaqaManagementTag({super.key, required this.label});

  final String label;

  double get _width {
    final normalized = label.toLowerCase();
    if (normalized.contains('exercise')) return 96;
    if (normalized.contains('not assigned')) return 100;
    if (normalized.contains('assigned')) return 90;
    return 62;
  }

  @override
  Widget build(BuildContext context) {
    return TaqaOutlineTagButton(
      label: label,
      width: TaqaUiScale.w(_width),
      height: TaqaUiScale.h(20),
    );
  }
}

class TaqaFloatingAddButton extends StatelessWidget {
  const TaqaFloatingAddButton({
    super.key,
    required this.loading,
    required this.onTap,
  });

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = TaqaUiScale.w(62);
    final radius = TaqaUiScale.r(31);
    final shape = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(radius),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: shape,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TaqaUiColors.white,
            borderRadius: shape,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: TaqaUiScale.r(30),
              ),
            ],
          ),
          child: loading
              ? SizedBox(
                  width: TaqaUiScale.w(18),
                  height: TaqaUiScale.h(18),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                )
              : Icon(
                  Icons.add,
                  size: TaqaUiScale.w(26),
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
        ),
      ),
    );
  }
}

class TaqaManagementListCard extends StatelessWidget {
  const TaqaManagementListCard({
    super.key,
    required this.child,
    this.onTap,
    this.minHeight,
    this.padding,
    this.radius = 5,
    this.showBorder = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? minHeight;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: TaqaUiScale.h(minHeight!)),
      padding: padding ?? TaqaUiScale.insetsLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: TaqaUiScale.radius(radius),
        border: showBorder
            ? Border.all(
                color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.10),
              )
            : null,
      ),
      child: child,
    );
    return Material(
      color: TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(radius),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: TaqaUiScale.radius(radius),
              child: content,
            ),
    );
  }
}

class TaqaCompactActionButton extends StatelessWidget {
  const TaqaCompactActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.color = TaqaUiColors.charcoal,
    this.height = 30,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: TaqaUiScale.radius(5),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: TaqaUiScale.radius(5),
        child: Container(
          height: TaqaUiScale.h(height),
          padding: TaqaUiScale.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: TaqaUiScale.radius(5),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: TaqaUiScale.w(13),
                  height: TaqaUiScale.h(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, size: TaqaUiScale.w(13), color: color),
              SizedBox(width: TaqaUiScale.w(5)),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(8),
                  fontWeight: FontWeight.w400,
                  height: 10 / 8,
                  letterSpacing: 0,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaqaIconActionButton extends StatelessWidget {
  const TaqaIconActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.loading = false,
    this.color = TaqaUiColors.charcoal,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool loading;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onTap,
      icon: loading
          ? SizedBox(
              width: TaqaUiScale.w(14),
              height: TaqaUiScale.h(14),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: TaqaUiColors.lime,
              ),
            )
          : Icon(icon, color: color, size: TaqaUiScale.w(iconSize)),
    );
  }
}

class TaqaExpertClientCard extends StatelessWidget {
  const TaqaExpertClientCard({
    super.key,
    required this.name,
    required this.status,
    required this.alerts,
    this.onTap,
    this.avatarUrl,
    this.subtitle,
    this.details = const [],
    this.footer,
    this.showStatus = true,
  });

  final String name;
  final String? avatarUrl;
  final String? status;
  final String? subtitle;
  final List<String> details;
  final Widget? footer;
  final bool showStatus;
  final List<String> alerts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TaqaManagementListCard(
      minHeight: 79,
      radius: 15,
      showBorder: false,
      onTap: onTap,
      child: Row(
        children: [
          TaqaClientAvatar(name: name, avatarUrl: avatarUrl),
          SizedBox(width: TaqaUiScale.w(12)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.charcoal,
                          fontWeight: FontWeight.w700,
                          fontSize: TaqaUiScale.sp(15),
                          height: 25 / 15,
                        ),
                      ),
                    ),
                    if (showStatus) ...[
                      SizedBox(width: TaqaUiScale.w(6)),
                      TaqaActivityStatus(status: status),
                    ],
                  ],
                ),
                if ((subtitle ?? '').trim().isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(2)),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      color: TaqaUiColors.charcoal,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w400,
                      height: 18 / 15,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                ...details
                    .where((detail) => detail.trim().isNotEmpty)
                    .map(
                      (detail) => Padding(
                        padding: EdgeInsets.only(top: TaqaUiScale.h(2)),
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            color: TaqaUiColors.charcoal,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w400,
                            height: 18 / 15,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                if (alerts.isNotEmpty) ...[
                  SizedBox(height: TaqaUiScale.h(4)),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: TaqaUiScale.h(33)),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        alerts.join('\n'),
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.unnamedColor1c1d17,
                          fontSize: TaqaUiScale.sp(15),
                          fontWeight: FontWeight.w400,
                          height: 18 / 15,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
                if (footer != null) ...[
                  SizedBox(height: TaqaUiScale.h(6)),
                  footer!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaActivityStatus extends StatelessWidget {
  const TaqaActivityStatus({super.key, required this.status});

  final String? status;

  Color get _color {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'green':
        return const Color(0xFF3BE971);
      case 'yellow':
        return const Color(0xFFF4C542);
      default:
        return const Color(0xFFE93B3B);
    }
  }

  String get _label =>
      (status ?? '').trim().toLowerCase() == 'green' ? 'ACTIVE' : 'INACTIVE';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: TaqaUiScale.w(6),
            height: TaqaUiScale.h(6),
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: 0.45),
                  blurRadius: TaqaUiScale.r(5),
                  spreadRadius: TaqaUiScale.r(0.5),
                ),
              ],
            ),
          ),
          SizedBox(width: TaqaUiScale.w(4)),
          Text(
            _label,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
              fontSize: TaqaUiScale.sp(8),
              fontWeight: FontWeight.w400,
              height: 10 / 8,
              letterSpacing: 0,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class TaqaAssignedClientsStack extends StatelessWidget {
  const TaqaAssignedClientsStack({
    super.key,
    required this.clients,
    required this.totalCount,
  });

  final List<Map<String, dynamic>> clients;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final preview = clients.take(3).toList(growable: false);
    final overflow = totalCount - preview.length;
    final baseWidth = preview.isEmpty ? 0 : (preview.length - 1) * 18 + 30;
    final totalWidth = baseWidth + (overflow > 0 ? 30 : 0);
    return SizedBox(
      width: TaqaUiScale.w(totalWidth),
      height: TaqaUiScale.h(30),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < preview.length; i++)
            PositionedDirectional(
              start: TaqaUiScale.w(i * 18),
              child: TaqaClientAvatar(
                name: (preview[i]['name'] ?? '').toString().trim(),
                avatarUrl: (preview[i]['avatar_url'] ?? '').toString().trim(),
                radius: 15,
              ),
            ),
          if (overflow > 0)
            PositionedDirectional(
              start: TaqaUiScale.w(baseWidth),
              child: CircleAvatar(
                radius: TaqaUiScale.r(15),
                backgroundColor: TaqaUiColors.charcoal.withValues(alpha: 0.12),
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: TaqaUiColors.charcoal,
                    fontSize: TaqaUiScale.sp(10),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TaqaClientAvatar extends StatelessWidget {
  const TaqaClientAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
  });

  final String name;
  final String? avatarUrl;
  final double radius;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl ?? '').trim();
    return CircleAvatar(
      radius: TaqaUiScale.r(radius),
      backgroundColor: TaqaUiColors.charcoal,
      foregroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onForegroundImageError: url.isNotEmpty ? (_, _) {} : null,
      child: url.isNotEmpty
          ? null
          : Text(
              _initials,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: TaqaUiColors.white,
                fontWeight: FontWeight.w700,
                fontSize: TaqaUiScale.sp(radius * 0.58),
              ),
            ),
    );
  }
}
