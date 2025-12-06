import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/base_url.dart';
import '../../theme/app_theme.dart';
import '../../theme/spacing.dart';
import '../../widgets/appbar_back_button.dart';
import '../../screens/welcome.dart';
import '../../localization/app_localizations.dart';
import 'reset_password_page.dart';
import '../../widgets/app_toast.dart';

class VerifyResetCodePage extends StatefulWidget {
  final String email;

  const VerifyResetCodePage({super.key, required this.email});

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

    final now = DateTime.now();
    final remaining = cooldownEndsAt!.difference(now).inSeconds;

    if (remaining > 0) {
      cooldownSeconds = remaining;
      resendCooldown = true;
      _startTimer();
    } else {
      resendCooldown = false;
    }
  }

  void _startCooldown() {
    cooldownEndsAt = DateTime.now().add(const Duration(seconds: 30));
    cooldownSeconds = 30;
    resendCooldown = true;
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final now = DateTime.now();

      if (cooldownEndsAt == null) {
        t.cancel();
        return;
      }

      final remaining = cooldownEndsAt!.difference(now).inSeconds;

      if (remaining <= 0) {
        t.cancel();
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

    final url = Uri.parse("${ApiConfig.baseUrl}/password/forgot");
    final body = jsonEncode({"email": widget.email});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        AppToast.show(
          context,
          t.translate("reset_code_resent"),
          type: AppToastType.success,
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
    }
  }

  Future<void> verifyCode() async {
    final t = AppLocalizations.of(context);
    final code = codeCtrl.text.trim();

    if (code.isEmpty) {
      if (!mounted) return;
      AppToast.show(
        context,
        t.translate("enter_reset_code"),
        type: AppToastType.error,
      );
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/password/verify");
    final body = jsonEncode({"email": widget.email, "code": code});

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              email: widget.email,
              code: code,
            ),
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
        title: Text(t.translate("verify_reset_code")),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate("reset_code_sent_to"),
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              widget.email,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Gaps.h20,
            TextField(
              controller: codeCtrl,
              decoration: InputDecoration(
                labelText: t.translate("code"),
                hintText: t.translate("hint_code"),
              ),
            ),
            Gaps.h20,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : verifyCode,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(t.translate("verify_btn")),
              ),
            ),
            Gaps.h20,
            Center(
              child: TextButton(
                onPressed: resendCooldown ? null : resendCode,
                child: resendCooldown
                    ? Text(
                        "${t.translate("resend_wait").replaceAll("{seconds}", cooldownSeconds.toString())}",
                        style: const TextStyle(color: Colors.grey),
                      )
                    : Text(
                        t.translate("resend_btn"),
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
