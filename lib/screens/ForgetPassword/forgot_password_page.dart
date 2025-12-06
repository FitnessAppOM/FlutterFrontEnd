import 'dart:convert';
import 'package:flutter/material.dart';
import '../../config/base_url.dart';
import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import '../welcome.dart';
import 'verify_reset_code_page.dart';
import '../../widgets/appbar_back_button.dart';
import 'package:http/http.dart' as http;
import '../../localization/app_localizations.dart';
import '../../widgets/app_toast.dart';

class ForgotPasswordPage extends StatefulWidget {
  final String? lockedEmail;
  final bool lockEmailField;

  const ForgotPasswordPage({super.key, this.lockedEmail, this.lockEmailField = false});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailCtrl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.lockedEmail != null && widget.lockEmailField) {
      emailCtrl.text = widget.lockedEmail!;
    }
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyResetCodePage(email: email),
          ),
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

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("forgot_password")),
        leading: AppBarBackButton(
          onTap: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomePage()),
                (route) => false,
              );
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              enabled: !(widget.lockEmailField && widget.lockedEmail != null),
              decoration: InputDecoration(
                labelText: t.translate("email"),
                hintText: "example@gmail.com",
              ),
            ),
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : sendResetCode,
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(t.translate("send_reset_code")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
