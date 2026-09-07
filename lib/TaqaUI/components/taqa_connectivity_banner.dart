import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/core/network_status_service.dart';
import '../../services/core/offline_sync_coordinator.dart';
import '../Typography/taqa_ui_typography.dart';
import '../styles/taqa_ui_scale.dart';
import '../taqa_ui_colors.dart';

class TaqaConnectivityBanner extends StatelessWidget {
  const TaqaConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final network = NetworkStatusService.instance;
    final sync = OfflineSyncCoordinator.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([network, sync]),
      builder: (context, _) {
        final presentation = _presentation(context, network, sync);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: presentation == null
              ? const SizedBox.shrink(key: ValueKey('connectivity-hidden'))
              : Padding(
                  key: ValueKey(presentation.keyName),
                  padding: TaqaUiScale.insetsLTRB(12, 6, 12, 6),
                  child: Semantics(
                    liveRegion: true,
                    label: presentation.message,
                    child: Material(
                      color: TaqaUiColors.charcoal,
                      borderRadius: TaqaUiScale.radius(15),
                      child: InkWell(
                        borderRadius: TaqaUiScale.radius(15),
                        onTap: presentation.canRetry
                            ? () => sync.syncNow()
                            : null,
                        child: Padding(
                          padding: TaqaUiScale.insetsLTRB(14, 10, 14, 10),
                          child: Row(
                            children: [
                              _StatusIcon(presentation: presentation),
                              SizedBox(width: TaqaUiScale.w(10)),
                              Expanded(
                                child: Text(
                                  presentation.message,
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(13),
                                    fontWeight: FontWeight.w600,
                                    height: 18 / 13,
                                    color: TaqaUiColors.white,
                                  ),
                                ),
                              ),
                              if (presentation.canRetry) ...[
                                SizedBox(width: TaqaUiScale.w(8)),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  ).translate('offline_retry'),
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(12),
                                    fontWeight: FontWeight.w700,
                                    color: TaqaUiColors.lime,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  _BannerPresentation? _presentation(
    BuildContext context,
    NetworkStatusService network,
    OfflineSyncCoordinator sync,
  ) {
    final t = AppLocalizations.of(context);
    if (network.isOffline) {
      return _BannerPresentation(
        keyName: 'offline',
        message: t.translate('offline_banner_cached'),
        icon: Icons.cloud_off_rounded,
      );
    }
    switch (sync.status) {
      case OfflineSyncStatus.syncing:
        return _BannerPresentation(
          keyName: 'syncing',
          message: t
              .translate('offline_banner_syncing')
              .replaceAll('{count}', sync.pendingCount.toString()),
          showProgress: true,
        );
      case OfflineSyncStatus.failed:
        return _BannerPresentation(
          keyName: 'failed',
          message: t
              .translate('offline_banner_failed')
              .replaceAll('{count}', sync.pendingCount.toString()),
          icon: Icons.sync_problem_rounded,
          isError: true,
          canRetry: true,
        );
      case OfflineSyncStatus.succeeded:
        return _BannerPresentation(
          keyName: 'succeeded',
          message: t.translate('offline_banner_synced'),
          icon: Icons.cloud_done_rounded,
        );
      case OfflineSyncStatus.idle:
        if (sync.pendingCount > 0) {
          return _BannerPresentation(
            keyName: 'pending',
            message: t
                .translate('offline_banner_pending')
                .replaceAll('{count}', sync.pendingCount.toString()),
            icon: Icons.cloud_upload_outlined,
            canRetry: network.isOnline,
          );
        }
        return null;
    }
  }
}

class TaqaOfflineEmptyState extends StatelessWidget {
  const TaqaOfflineEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: TaqaUiScale.insetsLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: TaqaUiScale.w(56),
              height: TaqaUiScale.h(56),
              decoration: const BoxDecoration(
                color: TaqaUiColors.lime,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: TaqaUiScale.w(28),
                color: TaqaUiColors.charcoal,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w600,
                color: TaqaUiColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.presentation});

  final _BannerPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TaqaUiScale.w(26),
      height: TaqaUiScale.h(26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: presentation.isError ? TaqaUiColors.recordRed : TaqaUiColors.lime,
        shape: BoxShape.circle,
      ),
      child: presentation.showProgress
          ? SizedBox(
              width: TaqaUiScale.w(14),
              height: TaqaUiScale.h(14),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: TaqaUiColors.charcoal,
              ),
            )
          : Icon(
              presentation.icon,
              size: TaqaUiScale.w(15),
              color: presentation.isError
                  ? TaqaUiColors.white
                  : TaqaUiColors.charcoal,
            ),
    );
  }
}

class _BannerPresentation {
  const _BannerPresentation({
    required this.keyName,
    required this.message,
    this.icon = Icons.sync_rounded,
    this.showProgress = false,
    this.isError = false,
    this.canRetry = false,
  });

  final String keyName;
  final String message;
  final IconData icon;
  final bool showProgress;
  final bool isError;
  final bool canRetry;
}
