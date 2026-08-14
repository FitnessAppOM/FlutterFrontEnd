import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_text_field.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../localization/app_localizations.dart';
import '../services/referrals/referral_api.dart';

Widget referralOnboardingIfNeeded({
  required Map<String, dynamic> profile,
  required Widget nextPage,
}) {
  return profile['referral_onboarding_status'] == 'pending'
      ? ReferralOnboardingPage(nextPage: nextPage)
      : nextPage;
}

class ReferralOnboardingPage extends StatefulWidget {
  const ReferralOnboardingPage({
    super.key,
    required this.nextPage,
  });

  final Widget nextPage;

  @override
  State<ReferralOnboardingPage> createState() =>
      _ReferralOnboardingPageState();
}

class _ReferralOnboardingPageState extends State<ReferralOnboardingPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => widget.nextPage),
      (_) => false,
    );
  }

  Future<void> _applyCode() async {
    final t = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _show(t.translate('referral_onboarding_code_required'));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ReferralApi.redeem(code, source: 'onboarding');
      if (!mounted) return;
      _continue();
    } on ReferralApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show(t.translate('referral_onboarding_error'));
    }
  }

  Future<void> _confirmSkip() async {
    final t = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaqaUiColors.white,
        title: Text(t.translate('referral_skip_title')),
        content: Text(t.translate('referral_skip_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.translate('referral_enter_code')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.translate('referral_continue_without')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ReferralApi.skipOnboarding();
      if (!mounted) return;
      _continue();
    } on ReferralApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _show(t.translate('referral_onboarding_error'));
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        appBar: TaqaPageAppBar(
          title: t.translate('referral_onboarding_title'),
          showBackButton: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: TaqaUiScale.insetsLTRB(16, 22, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: TaqaUiScale.w(54),
                  height: TaqaUiScale.w(54),
                  decoration: BoxDecoration(
                    color: TaqaUiColors.unnamedColorE4e93b,
                    borderRadius: TaqaUiScale.radius(14),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(20)),
                Text(
                  t.translate('referral_onboarding_heading'),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(24),
                    fontWeight: FontWeight.w700,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(8)),
                Text(
                  t.translate('referral_onboarding_body'),
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(14),
                    height: 1.4,
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.65),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(28)),
                TaqaTextField(
                  controller: _codeController,
                  label: t.translate('referral_onboarding_code_label'),
                  hint: t.translate('referral_onboarding_code_hint'),
                  enabled: !_submitting,
                  textInputAction: TextInputAction.done,
                  maxLength: 32,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    _UpperCaseTextFormatter(),
                  ],
                ),
                const Spacer(),
                TaqaFilledButton(
                  label: t.translate('referral_apply_code'),
                  loading: _submitting,
                  onTap: _submitting ? null : _applyCode,
                ),
                SizedBox(height: TaqaUiScale.h(6)),
                TaqaTextActionButton(
                  label: t.translate('referral_no_code'),
                  onTap: _submitting ? null : _confirmSkip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
