import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/account_storage.dart';
import '../core/account_type.dart';
import '../config/base_url.dart';
import '../localization/app_localizations.dart'; // ADDED
import 'verification_success_page.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_underline_field.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../services/core/notification_service.dart';
import '../services/core/daily_provider_push_service.dart';

class EmailVerificationPage extends StatefulWidget {
  final String? email;
  final bool isExpert;
  final bool initialDeliveryPending;
  final bool studentPlanVerification;

  const EmailVerificationPage({
    super.key,
    this.email,
    this.isExpert = false,
    this.initialDeliveryPending = false,
    this.studentPlanVerification = false,
  }) : assert(email != null || studentPlanVerification);

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController studentEmailController = TextEditingController();

  bool loading = false;
  bool _studentCodeSent = false;
  String? _studentEmail;

  bool resendCooldown = false;
  int cooldownSeconds = 30;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    if (widget.initialDeliveryPending) {
      _startResendCooldown();
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    studentEmailController.dispose();
    timer?.cancel();
    super.dispose();
  }

  // ---------------- VERIFY CODE ----------------
  Future<void> verifyCode() async {
    if (widget.studentPlanVerification) {
      await _verifyStudentCode();
      return;
    }
    final t = AppLocalizations.of(context);

    final code = codeController.text.trim();

    if (code.length != 6) {
      _show(t.translate("code_invalid"));
      return;
    }

    setState(() => loading = true);

    final url = Uri.parse("${ApiConfig.baseUrl}/auth/verify-email");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email!, "code": code}),
      );

      setState(() => loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        final rawId = data["user_id"] ?? data["id"];
        final int userId = rawId is int
            ? rawId
            : (int.tryParse(rawId?.toString() ?? '') ?? 0);
        final email = widget.email!;
        final token =
            (data["access_token"] ??
                    data["accessToken"] ??
                    data["jwt"] ??
                    data["token"])
                ?.toString()
                .trim();

        if (userId <= 0) {
          _show(t.translate("network_error"));
          return;
        }
        final isCoachAccount = AccountType.isCoach(data) || widget.isExpert;

        await AccountStorage.saveUserSession(
          userId: userId,
          email: email,
          name: email.split('@').first,
          verified: true,
          token: token,
          refreshToken: data["refresh_token"]?.toString(),
          isExpert: isCoachAccount,
          questionnaireDone: false,
          expertQuestionnaireDone: false,
          authProvider: "email",
        );
        await AccountStorage.markSkipDailyJournalPromptForNextSession(
          userId: userId,
        );

        if (!mounted) return;

        final canContinue = token != null && token.isNotEmpty;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationSuccessPage(
              email: email,
              isExpert: isCoachAccount,
              canContinue: canContinue,
            ),
          ),
        );
        // Fire-and-forget: do not block navigation if these fail.
        NotificationService.refreshDailyJournalRemindersForCurrentUser();
        if (token != null && token.isNotEmpty) {
          DailyProviderPushService().pushIfAfterOneAmLocal().catchError((_) {});
        }
        return;
      } else {
        String msg = t.translate("verified_failed");
        try {
          msg = (jsonDecode(response.body)["detail"] ?? msg).toString();
        } catch (_) {}
        _show(msg);
      }
    } catch (e) {
      setState(() => loading = false);
      _show("${t.translate("network_error")}: $e");
    }
  }

  // ---------------- RESEND CODE ----------------
  Future<void> resendCode() async {
    if (widget.studentPlanVerification) {
      await _startStudentVerification(resend: true);
      return;
    }
    final t = AppLocalizations.of(context);

    if (resendCooldown) return;

    _startResendCooldown();

    final url = Uri.parse("${ApiConfig.baseUrl}/auth/resend-verification");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email}),
      );

      if (response.statusCode == 200) {
        _show(t.translate("resend_success"));
      } else {
        String msg = t.translate("resend_failed");
        try {
          msg = (jsonDecode(response.body)["detail"] ?? msg).toString();
        } catch (_) {}
        _show(msg);
      }
    } catch (e) {
      _show("${t.translate("network_error")}: $e");
    }
  }

  Future<void> _startStudentVerification({bool resend = false}) async {
    if (resend && resendCooldown) return;
    final email = studentEmailController.text.trim().toLowerCase();
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      _show('Enter your institution email address.');
      return;
    }

    final authHeaders = await AccountStorage.getAuthHeaders();
    if (!authHeaders.containsKey('Authorization')) {
      _show('Please sign in again before verifying your student status.');
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/student-verification/start'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({'email': email}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _studentEmail = email;
          _studentCodeSent = true;
          loading = false;
        });
        _startResendCooldown();
        _show(
          resend
              ? 'A new verification code was sent.'
              : 'Verification code sent.',
        );
        return;
      }
      setState(() => loading = false);
      _show(_responseMessage(response, 'Could not send a verification code.'));
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      _show('Network error: $error');
    }
  }

  Future<void> _verifyStudentCode() async {
    final code = codeController.text.trim();
    if (code.length != 6) {
      _show('Enter the 6-digit verification code.');
      return;
    }

    final authHeaders = await AccountStorage.getAuthHeaders();
    if (!authHeaders.containsKey('Authorization')) {
      _show('Please sign in again before verifying your student status.');
      return;
    }

    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/student-verification/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...authHeaders,
        },
        body: jsonEncode({'code': code}),
      );
      if (!mounted) return;
      setState(() => loading = false);
      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
        return;
      }
      _show(
        _responseMessage(response, 'Could not verify your student status.'),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      _show('Network error: $error');
    }
  }

  String _responseMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  void _startResendCooldown() {
    timer?.cancel();
    if (mounted) {
      setState(() {
        resendCooldown = true;
        cooldownSeconds = 30;
      });
    } else {
      resendCooldown = true;
      cooldownSeconds = 30;
    }

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        cooldownSeconds--;
        if (cooldownSeconds <= 0) {
          resendCooldown = false;
          timer.cancel();
        }
      });
    });
  }

  // ---------------- helpers ----------------
  void _show(String text, {AppToastType type = AppToastType.info}) {
    if (!mounted) return;
    AppToast.show(context, text, type: type);
  }

  String _obfuscateEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    final visible = name.length <= 2
        ? name
        : "${name.substring(0, 2)}${'*' * (name.length - 2)}";
    return "$visible@$domain";
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // Translator
    final isStudentFlow = widget.studentPlanVerification;
    final canSubmit =
        !loading &&
        (isStudentFlow && !_studentCodeSent
            ? studentEmailController.text.trim().contains('@')
            : codeController.text.trim().length == 6);

    final bodyStyle = TextStyle(
      fontFamily: TaqaUiFontFamilies.interTight,
      fontSize: TaqaUiScale.sp(14),
      fontWeight: FontWeight.w400,
      color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.7),
    );

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: isStudentFlow
            ? 'Verify student status'
            : t.translate("verification_title"),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isStudentFlow && !_studentCodeSent) ...[
                    Text(
                      'Enter the email provided by your selected university. We will send a code before you can purchase the student plan.',
                      style: bodyStyle,
                    ),
                    SizedBox(height: TaqaUiScale.h(24)),
                    TaqaUnderlineTextField(
                      controller: studentEmailController,
                      label: 'Institution email',
                      hint: 'you@university.edu',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else ...[
                    Text(
                      isStudentFlow
                          ? 'Enter the code sent to your institution email.'
                          : t.translate("verification_sent"),
                      style: bodyStyle,
                    ),
                    if (widget.initialDeliveryPending) ...[
                      SizedBox(height: TaqaUiScale.h(8)),
                      Text(
                        'Your account was created, but the first email was delayed. '
                        'Use Resend Code when the timer finishes.',
                        style: bodyStyle.copyWith(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: TaqaUiScale.h(6)),
                    Text(
                      _obfuscateEmail(_studentEmail ?? widget.email ?? ''),
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      t.translate("verification_spam_hint"),
                      style: bodyStyle.copyWith(
                        fontSize: TaqaUiScale.sp(12),
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(24)),
                    TaqaUnderlineTextField(
                      controller: codeController,
                      label: t.translate("enter_code"),
                      hint: t.translate("hint_code"),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: TaqaUiScale.h(20)),
                    Center(
                      child: resendCooldown
                          ? Text(
                              t
                                  .translate("resend_wait")
                                  .replaceAll("{seconds}", "$cooldownSeconds"),
                              style: bodyStyle,
                            )
                          : TaqaTextActionButton(
                              label: t.translate("resend_btn"),
                              onTap: resendCode,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 0, 16, 20),
            child: TaqaFilledButton(
              label: isStudentFlow && !_studentCodeSent
                  ? 'Send verification code'
                  : t.translate("verify_btn"),
              onTap: canSubmit
                  ? () {
                      if (isStudentFlow && !_studentCodeSent) {
                        _startStudentVerification();
                      } else {
                        verifyCode();
                      }
                    }
                  : null,
              loading: loading,
            ),
          ),
        ],
      ),
    );
  }
}
