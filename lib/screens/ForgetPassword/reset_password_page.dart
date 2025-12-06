import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import '../../widgets/appbar_back_button.dart';
import '../../auth/login.dart';
import '../../screens/welcome.dart';
import '../../localization/app_localizations.dart';
import '../../widgets/app_toast.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController pwCtrl = TextEditingController();
  final TextEditingController retypeCtrl = TextEditingController();

  bool loading = false;

  Future<void> resetPassword() async {
    final t = AppLocalizations.of(context);

    final newPw = pwCtrl.text.trim();
    final rePw = retypeCtrl.text.trim();

    if (newPw.isEmpty || rePw.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("fill_all_fields"),
        type: AppToastType.error,
      );
      return;
    }

    if (newPw != rePw) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("passwords_do_not_match"),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/password/reset");

    final body = jsonEncode({
      "email": widget.email,
      "code": widget.code,
      "new_password": newPw,
    });

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode != 200) {
        if (!mounted) return;
        AppToast.show(
          context,
          data?["detail"] ?? t.translate("reset_failed"),
          type: AppToastType.error,
        );
        return;
      }

      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("password_reset_success"),
        type: AppToastType.success,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        "${t.translate("network_error")}: $e",
        type: AppToastType.error,
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(t.translate("reset_password")),
        leading: AppBarBackButton(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WelcomePage()),
              (route) => false,
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.translate("new_password"),
              ),
            ),
            Gaps.h12,
            TextField(
              controller: retypeCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.translate("retype_password"),
              ),
            ),
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : resetPassword,
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(t.translate("reset_password")),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
