import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../auth/login.dart';
import '../../config/base_url.dart';
import '../../localization/app_localizations.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
import '../../TaqaUI/components/taqa_filled_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_text_field.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/taqa_ui_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.email, required this.code});

  final String email;
  final String code;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController pwCtrl = TextEditingController();
  final TextEditingController retypeCtrl = TextEditingController();

  bool loading = false;
  bool newPasswordVisible = false;
  bool confirmationVisible = false;

  @override
  void dispose() {
    pwCtrl.dispose();
    retypeCtrl.dispose();
    super.dispose();
  }

  Future<void> resetPassword() async {
    final t = AppLocalizations.of(context);
    final newPassword = pwCtrl.text.trim();
    final confirmation = retypeCtrl.text.trim();

    if (newPassword.isEmpty || confirmation.isEmpty) {
      AppToast.show(
        context,
        t.translate('fill_all_fields'),
        type: AppToastType.error,
      );
      return;
    }

    if (newPassword != confirmation) {
      AppToast.show(
        context,
        t.translate('passwords_do_not_match'),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'code': widget.code,
          'new_password': newPassword,
        }),
      );
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (!mounted) return;
      if (response.statusCode != 200) {
        AppToast.show(
          context,
          data?['detail'] ?? t.translate('reset_failed'),
          type: AppToastType.error,
        );
        return;
      }

      AppToast.show(
        context,
        t.translate('password_reset_success'),
        type: AppToastType.success,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
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
    final canSubmit =
        !loading && pwCtrl.text.isNotEmpty && retypeCtrl.text.isNotEmpty;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(title: t.translate('reset_password')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          t.translate('password_reset_new_subtitle'),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(14),
                            fontWeight: FontWeight.w400,
                            height: 20 / 14,
                            color: TaqaUiColors.unnamedColor1c1d17.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(24)),
                        TaqaTextField(
                          controller: pwCtrl,
                          label: t.translate('new_password'),
                          hint: t.translate('password_hint'),
                          obscureText: !newPasswordVisible,
                          textInputAction: TextInputAction.next,
                          maxLength: 128,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => setState(() {}),
                          suffixIcon: TaqaPasswordVisibilityButton(
                            visible: newPasswordVisible,
                            onTap: () => setState(
                              () => newPasswordVisible = !newPasswordVisible,
                            ),
                          ),
                        ),
                        SizedBox(height: TaqaUiScale.h(12)),
                        TaqaTextField(
                          controller: retypeCtrl,
                          label: t.translate('retype_password'),
                          hint: t.translate('password_hint'),
                          obscureText: !confirmationVisible,
                          textInputAction: TextInputAction.done,
                          maxLength: 128,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => setState(() {}),
                          suffixIcon: TaqaPasswordVisibilityButton(
                            visible: confirmationVisible,
                            onTap: () => setState(
                              () => confirmationVisible = !confirmationVisible,
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
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: TaqaFilledButton(
                  label: t.translate('reset_password'),
                  loading: loading,
                  onTap: canSubmit ? resetPassword : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
