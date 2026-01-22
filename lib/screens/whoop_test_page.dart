import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/primary_button.dart';

class WhoopTestPage extends StatefulWidget {
  const WhoopTestPage({super.key});

  @override
  State<WhoopTestPage> createState() => _WhoopTestPageState();
}

class _WhoopTestPageState extends State<WhoopTestPage> {
  int? _userId;
  bool _loading = true;
  String? _statusMessage;
  bool _statusOk = false;
  bool _profileLoading = false;
  Map<String, dynamic>? _whoopData;
  String? _whoopError;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final userId = await AccountStorage.getUserId();
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _loading = false;
    });
  }

  Future<void> _connectWhoop() async {
    if (_userId == null || _userId == 0) {
      AppToast.show(
        context,
        "Please log in to connect Whoop.",
        type: AppToastType.info,
      );
      return;
    }

    setState(() {
      _statusMessage = null;
      _statusOk = false;
    });

    final url = "${ApiConfig.baseUrl}/auth/whoop/login?user_id=$_userId";
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'taqa',
      );
      final uri = Uri.tryParse(result);
      final ok = uri != null &&
          uri.scheme == 'taqa' &&
          uri.host == 'whoop' &&
          uri.path == '/success';
      if (!mounted) return;
      setState(() {
        _statusOk = ok;
        _statusMessage = ok ? "Whoop connected successfully." : "Whoop connect failed.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusOk = false;
        _statusMessage = "Whoop connect failed.";
      });
      AppToast.show(
        context,
        "Whoop connect failed: $e",
        type: AppToastType.error,
      );
    }
  }

  Future<void> _loadWhoopData() async {
    if (_userId == null || _userId == 0) {
      AppToast.show(
        context,
        "Please log in to fetch Whoop data.",
        type: AppToastType.info,
      );
      return;
    }

    setState(() {
      _profileLoading = true;
      _whoopError = null;
      _whoopData = null;
    });

    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/whoop/latest?user_id=$_userId",
      );
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception("Status ${response.statusCode}");
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _whoopData = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _whoopError = "Failed to load Whoop data: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _profileLoading = false;
        });
      }
    }
  }

  Widget _buildDataSection(String title, dynamic data) {
    if (data == null) {
      return Text(
        "$title: no data",
        style: const TextStyle(color: Colors.white54),
      );
    }
    final formatted = const JsonEncoder.withIndent('  ').convert(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatted,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text("Whoop Test"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loading
                        ? "Loading user..."
                        : _userId == null
                            ? "No user found"
                            : "User id: $_userId",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryWhiteButton(
                      onPressed: _loading ? null : _connectWhoop,
                      child: const Text("Connect Whoop"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryWhiteButton(
                      onPressed: (!_statusOk || _profileLoading) ? null : _loadWhoopData,
                      child: _profileLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Show Whoop Data"),
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusOk ? Colors.greenAccent : Colors.redAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_whoopError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _whoopError!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_whoopData != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDataSection("Profile", _whoopData!["profile"]),
                          const SizedBox(height: 12),
                          _buildDataSection("Recovery", _whoopData!["recovery"]),
                          const SizedBox(height: 12),
                          _buildDataSection("Cycles", _whoopData!["cycles"]),
                          const SizedBox(height: 12),
                          _buildDataSection("Sleep", _whoopData!["sleep"]),
                          const SizedBox(height: 12),
                          _buildDataSection("Workout", _whoopData!["workout"]),
                          const SizedBox(height: 12),
                          _buildDataSection("Body Measurement", _whoopData!["body_measurement"]),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
