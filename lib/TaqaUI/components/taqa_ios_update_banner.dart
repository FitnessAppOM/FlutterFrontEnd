import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/core/app_release_policy_service.dart';
import '../styles/taqa_ui_scale.dart';
import '../Typography/taqa_ui_typography.dart';
import '../taqa_ui_colors.dart';

class TaqaIosUpdateBanner extends StatelessWidget {
  const TaqaIosUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppReleasePolicyService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isVisible) return const SizedBox.shrink();
        final policy = service.policy!;
        final t = AppLocalizations.of(context);
        final fallback = t.translate(
          policy.updateRequired
              ? 'app_update_required'
              : 'app_update_available',
        );

        return SafeArea(
          top: false,
          bottom: false,
          child: Material(
            color: TaqaUiColors.charcoal,
            child: Padding(
              padding: TaqaUiScale.insetsLTRB(14, 9, 8, 9),
              child: Row(
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: TaqaUiScale.w(20),
                    color: TaqaUiColors.lime,
                  ),
                  SizedBox(width: TaqaUiScale.w(10)),
                  Expanded(
                    child: Text(
                      policy.message.isEmpty ? fallback : policy.message,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w600,
                        height: 18 / 13,
                        color: TaqaUiColors.white,
                      ),
                    ),
                  ),
                  if (!policy.updateRequired)
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
                  TextButton(
                    onPressed: service.openStore,
                    style: TextButton.styleFrom(
                      foregroundColor: TaqaUiColors.lime,
                      visualDensity: VisualDensity.compact,
                      padding: TaqaUiScale.insetsLTRB(8, 7, 8, 7),
                    ),
                    child: Text(
                      t.translate('app_update_action'),
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
        );
      },
    );
  }
}

class TaqaRequiredUpdateOverlay extends StatelessWidget {
  const TaqaRequiredUpdateOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppReleasePolicyService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isRequiredUpdateVisible) {
          return const SizedBox.shrink();
        }
        final policy = service.policy!;
        final t = AppLocalizations.of(context);
        return Positioned.fill(
          child: Material(
            color: TaqaUiColors.charcoal.withValues(alpha: 0.96),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(TaqaUiScale.w(24)),
                  child: Container(
                    constraints: BoxConstraints(maxWidth: TaqaUiScale.w(420)),
                    padding: EdgeInsets.all(TaqaUiScale.w(24)),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.white,
                      borderRadius: BorderRadius.circular(TaqaUiScale.w(24)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.system_update_rounded,
                          size: TaqaUiScale.w(48),
                          color: TaqaUiColors.charcoal,
                        ),
                        SizedBox(height: TaqaUiScale.h(16)),
                        Text(
                          t.translate('app_update_required'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(22),
                            fontWeight: FontWeight.w800,
                            color: TaqaUiColors.charcoal,
                          ),
                        ),
                        if (policy.message.isNotEmpty) ...[
                          SizedBox(height: TaqaUiScale.h(10)),
                          Text(
                            policy.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(14),
                              height: 1.4,
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.76,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: TaqaUiScale.h(22)),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: service.openStore,
                            style: FilledButton.styleFrom(
                              backgroundColor: TaqaUiColors.lime,
                              foregroundColor: TaqaUiColors.charcoal,
                              padding: EdgeInsets.symmetric(
                                vertical: TaqaUiScale.h(14),
                              ),
                            ),
                            child: Text(
                              t.translate('app_update_action'),
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
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
}
