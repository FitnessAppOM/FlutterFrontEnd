import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../config/base_url.dart';
import '../../localization/app_localizations.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_text_field.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import 'reset_password_page.dart';

class VerifyResetCodePage extends StatefulWidget {
  const VerifyResetCodePage({super.key, required this.email});

  final String email;

  @override
  State<VerifyResetCodePage> createState() => _VerifyResetCodePageState();
}

class _VerifyResetCodePageState extends State<VerifyResetCodePage> {
  final TextEditingController codeCtrl = TextEditingController();

  bool loading = false;
  bool resendCooldown = false;
  int cooldownSeconds = 30;
  Timer? timer;
  DateTime? cooldownEndsAt;

  @override
  void initState() {
    super.initState();
    _restoreCooldown();
  }

  @override
  void dispose() {
    timer?.cancel();
    codeCtrl.dispose();
    super.dispose();
  }

  void _restoreCooldown() {
    if (cooldownEndsAt == null) return;

    final remaining = cooldownEndsAt!.difference(DateTime.now()).inSeconds;
    if (remaining > 0) {
      cooldownSeconds = remaining;
      resendCooldown = true;
      _startTimer();
    } else {
      resendCooldown = false;
    }
  }

  void _startCooldown() {
    setState(() {
      cooldownEndsAt = DateTime.now().add(const Duration(seconds: 30));
      cooldownSeconds = 30;
      resendCooldown = true;
    });
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (activeTimer) {
      if (!mounted || cooldownEndsAt == null) {
        activeTimer.cancel();
        return;
      }

      final remaining = cooldownEndsAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        activeTimer.cancel();
        setState(() => resendCooldown = false);
      } else {
        setState(() => cooldownSeconds = remaining);
      }
    });
  }

  Future<void> resendCode() async {
    if (resendCooldown) return;

    final t = AppLocalizations.of(context);
    _startCooldown();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/password/forgot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        AppToast.show(
          context,
          t.translate('reset_code_resent'),
          type: AppToastType.success,
        );
      } else {
        final data = jsonDecode(response.body);
        AppToast.show(
          context,
          data['detail'].toString(),
          type: AppToastType.error,
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        '${t.translate('network_error')}: $error',
        type: AppToastType.error,
      );
    }
  }

  Future<void> verifyCode() async {
    final t = AppLocalizations.of(context);
    final code = codeCtrl.text.trim();

    if (code.length != 6) {
      AppToast.show(
        context,
        t.translate('enter_reset_code'),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/password/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': code}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(email: widget.email, code: code),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        AppToast.show(
          context,
          data['detail'].toString(),
          type: AppToastType.error,
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        '${t.translate('network_error')}: $error',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSubmit = !loading && codeCtrl.text.trim().length == 6;
    final bodyStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(14),
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.65),
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(title: t.translate('verify_reset_code')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        t.translate('password_reset_verify_subtitle'),
                        style: bodyStyle,
                      ),
                      SizedBox(height: TaqaUiScale.h(6)),
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          fontSize: TaqaUiScale.sp(15),
                          fontWeight: FontWeight.w700,
                          color: TaqaUiColors.unnamedColor1c1d17,
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(24)),
                      TaqaTextField(
                        controller: codeCtrl,
                        label: t.translate('code'),
                        hint: t.translate('hint_code'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onChanged: (_) => setState(() {}),
                      ),
                      SizedBox(height: TaqaUiScale.h(18)),
                      if (resendCooldown)
                        Center(
                          child: Text(
                            t
                                .translate('resend_wait')
                                .replaceAll(
                                  '{seconds}',
                                  cooldownSeconds.toString(),
                                ),
                            style: bodyStyle.copyWith(
                              fontSize: TaqaUiScale.sp(12),
                            ),
                          ),
                        )
                      else
                        TaqaTextActionButton(
                          label: t.translate('resend_btn'),
                          onTap: resendCode,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: TaqaFilledButton(
                  label: t.translate('verify_btn'),
                  loading: loading,
                  onTap: canSubmit ? verifyCode : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
