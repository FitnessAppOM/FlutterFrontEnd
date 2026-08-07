import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'verify_reset_code_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? lockedEmail;
  final bool lockEmailField;

  const ForgotPasswordPage({
    super.key,
    this.lockedEmail,
    this.lockEmailField = false,
  });

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lockedEmail != null) {
      emailCtrl.text = widget.lockedEmail!;
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> sendResetCode() async {
    final t = AppLocalizations.of(context);
    final email = widget.lockEmailField && widget.lockedEmail != null
        ? widget.lockedEmail!.trim()
        : emailCtrl.text.trim();

    if (email.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("error_required_fields"),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/password/forgot");
    final body = jsonEncode({"email": email});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyResetCodePage(email: email)),
        );
      } else {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        AppToast.show(
          context,
          data["detail"].toString(),
          type: AppToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("network_error")}: $e",
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final emailLocked = widget.lockEmailField && widget.lockedEmail != null;
    final canSubmit = !loading && emailCtrl.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(title: t.translate("forgot_password")),
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
                        t.translate("password_reset_request_subtitle"),
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
                        controller: emailCtrl,
                        label: t.translate("email"),
                        hint: t.translate("email_hint"),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        enabled: !emailLocked,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => setState(() {}),
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
                  label: t.translate("send_reset_code"),
                  loading: loading,
                  onTap: canSubmit ? sendResetCode : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
