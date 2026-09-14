import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/core/play_in_app_update_service.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaPlayUpdateBanner extends StatelessWidget {
  const TaqaPlayUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PlayInAppUpdateService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.isVisible) return const SizedBox.shrink();
        final t = AppLocalizations.of(context);
        final status = service.status;
        final isAvailable = status == PlayInAppUpdateStatus.available;
        final isDownloaded = status == PlayInAppUpdateStatus.downloaded;
        final isWorking =
            status == PlayInAppUpdateStatus.pending ||
            status == PlayInAppUpdateStatus.downloading ||
            status == PlayInAppUpdateStatus.installing;
        final progress = service.downloadProgress;

        String message;
        if (isDownloaded) {
          message = t.translate('app_update_ready');
        } else if (status == PlayInAppUpdateStatus.downloading) {
          message = t
              .translate('app_update_downloading')
              .replaceAll(
                '{percent}',
                progress == null ? '' : '${(progress * 100).round()}%',
              );
        } else if (status == PlayInAppUpdateStatus.installing) {
          message = t.translate('app_update_installing');
        } else if (status == PlayInAppUpdateStatus.pending) {
          message = t.translate('app_update_starting');
        } else {
          message = t.translate('app_update_available');
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Padding(
            key: ValueKey(status),
            padding: TaqaUiScale.insetsLTRB(12, 6, 12, 6),
            child: Material(
              color: TaqaUiColors.charcoal,
              borderRadius: TaqaUiScale.radius(15),
              child: Semantics(
                liveRegion: true,
                label: message,
                child: Padding(
                  padding: TaqaUiScale.insetsLTRB(14, 9, 10, 9),
                  child: Row(
                    children: [
                      Container(
                        width: TaqaUiScale.w(28),
                        height: TaqaUiScale.h(28),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: TaqaUiColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: isWorking
                            ? SizedBox(
                                width: TaqaUiScale.w(15),
                                height: TaqaUiScale.h(15),
                                child: CircularProgressIndicator(
                                  value:
                                      status ==
                                          PlayInAppUpdateStatus.downloading
                                      ? progress
                                      : null,
                                  strokeWidth: 2,
                                  color: TaqaUiColors.charcoal,
                                ),
                              )
                            : Icon(
                                isDownloaded
                                    ? Icons.system_update_alt_rounded
                                    : Icons.new_releases_rounded,
                                size: TaqaUiScale.w(16),
                                color: TaqaUiColors.charcoal,
                              ),
                      ),
                      SizedBox(width: TaqaUiScale.w(10)),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(13),
                            fontWeight: FontWeight.w600,
                            height: 18 / 13,
                            color: TaqaUiColors.white,
                          ),
                        ),
                      ),
                      if (isAvailable)
                        IconButton(
                          tooltip: t.translate('common_close'),
                          onPressed: service.dismissForToday,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            color: TaqaUiColors.white.withValues(alpha: 0.72),
                            size: TaqaUiScale.w(18),
                          ),
                        ),
                      if (isAvailable || isDownloaded)
                        TextButton(
                          onPressed: isDownloaded
                              ? service.completeFlexibleUpdate
                              : service.startFlexibleUpdate,
                          style: TextButton.styleFrom(
                            foregroundColor: TaqaUiColors.lime,
                            visualDensity: VisualDensity.compact,
                            padding: TaqaUiScale.insetsLTRB(8, 7, 8, 7),
                          ),
                          child: Text(
                            t.translate(
                              isDownloaded
                                  ? 'app_update_restart'
                                  : 'app_update_action',
                            ),
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(12),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
