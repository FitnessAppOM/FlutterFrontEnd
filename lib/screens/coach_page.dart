import 'package:flutter/material.dart';

import '../core/account_storage.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/coach/coach_feedback_panel.dart';
import '../widgets/coach/coach_form_check_panel.dart';
import '../widgets/coach/coach_info_panel.dart';
import '../widgets/confirm_dialog.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  List<_CoachAssignment> _assignedCoaches = const [];
  bool _profileLoaded = false;
  final Set<int> _detachingCoachIds = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileLoaded) return;
    _profileLoaded = true;
    _loadAssignedCoaches();
  }

  Future<void> _loadAssignedCoaches() async {
    try {
      final userId = await AccountStorage.getUserId();
      if (userId == null || userId <= 0) return;
      if (!mounted) return;
      final lang = AppLocalizations.of(context).locale.languageCode;
      final profile = await ProfileApi.fetchProfile(userId, lang: lang);
      final coaches = _parseAssignedCoaches(profile);
      if (!mounted) return;
      setState(() {
        _assignedCoaches = coaches;
      });
    } catch (_) {
      // Keep page usable when coach assignment is unavailable.
    }
  }

  String? _formatSpecialtyLabel(String raw) {
    if (raw.isEmpty) return null;
    final parts = raw.split('_').where((part) => part.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts
        .map((part) {
          final cleaned = part.trim();
          return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
        })
        .join(' ');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<_CoachAssignment> _parseAssignedCoaches(Map<String, dynamic> profile) {
    final coaches = <_CoachAssignment>[];
    final rawExperts = profile['assigned_experts'];
    if (rawExperts is List) {
      for (final item in rawExperts) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = (map['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final specialty = _formatSpecialtyLabel(
          (map['specialty'] ?? '').toString().trim(),
        );
        coaches.add(
          _CoachAssignment(
            id: _parseInt(map['id']),
            name: name,
            specialty: specialty,
          ),
        );
      }
    }

    // Backward compatibility with older backend payload.
    if (coaches.isEmpty) {
      final singleName = (profile['assigned_expert_name'] ?? '')
          .toString()
          .trim();
      if (singleName.isNotEmpty) {
        final singleSpecialty = _formatSpecialtyLabel(
          (profile['assigned_expert_specialty'] ?? '').toString().trim(),
        );
        coaches.add(
          _CoachAssignment(
            id: _parseInt(profile['assigned_expert_id']),
            name: singleName,
            specialty: singleSpecialty,
          ),
        );
      }
    }
    return coaches;
  }

  Future<void> _detachCoach(_CoachAssignment coach) async {
    final coachId = coach.id;
    if (coachId == null || coachId <= 0) {
      AppToast.show(
        context,
        "This coach cannot be detached right now.",
        type: AppToastType.error,
      );
      return;
    }
    if (_detachingCoachIds.contains(coachId)) return;

    final confirm = await showConfirmDialog(
      context: context,
      title: "Detach Coach",
      message: "Detach from ${coach.name}?",
      confirmText: "Detach",
    );
    if (confirm != true) return;

    setState(() => _detachingCoachIds.add(coachId));
    try {
      await ProfileApi.detachCoach(expertUserId: coachId);
      await _loadAssignedCoaches();
      if (!mounted) return;
      AppToast.show(
        context,
        "Detached from ${coach.name}.",
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, "Detach failed: $e", type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _detachingCoachIds.remove(coachId));
      }
    }
  }

  Future<void> _connectCoachByCode(String rawCode) async {
    final code = rawCode.replaceAll(RegExp(r'\s+'), '');
    if (code.isEmpty) {
      AppToast.show(
        context,
        "Enter a 6-digit coach code.",
        type: AppToastType.info,
      );
      return;
    }

    try {
      final result = await ProfileApi.connectCoachByCode(code: code);
      await _loadAssignedCoaches();
      if (!mounted) return;

      final name = (result['name'] ?? 'Coach').toString();
      final alreadyConnected = result['already_connected'] == true;
      AppToast.show(
        context,
        alreadyConnected
            ? "Already connected to $name."
            : "Connected to $name.",
        type: alreadyConnected ? AppToastType.info : AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, "Connect failed: $e", type: AppToastType.error);
    }
  }

  Future<void> _openCoachesSheet() async {
    final coaches = List<_CoachAssignment>.from(_assignedCoaches);
    final codeController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_2_outlined, color: Colors.white70),
                    const SizedBox(width: 8),
                    const Text(
                      'My Coaches',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "Enter 6-digit coach code",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final code = codeController.text.trim();
                      Navigator.of(sheetContext).pop();
                      await _connectCoachByCode(code);
                    },
                    icon: const Icon(Icons.link),
                    label: const Text("Connect"),
                  ),
                ),
                const SizedBox(height: 12),
                if (coaches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No coaches connected.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                if (coaches.isNotEmpty)
                  ...coaches.map((coach) {
                    final coachId = coach.id;
                    final isDetaching =
                        coachId != null &&
                        coachId > 0 &&
                        _detachingCoachIds.contains(coachId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white70,
                        ),
                        title: Text(
                          coach.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: (coach.specialty ?? '').isEmpty
                            ? null
                            : Text(
                                coach.specialty!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: TextButton.icon(
                          onPressed:
                              (coachId == null || coachId <= 0 || isDetaching)
                              ? null
                              : () async {
                                  Navigator.of(sheetContext).pop();
                                  await _detachCoach(coach);
                                },
                          icon: isDetaching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link_off, size: 18),
                          label: const Text('Detach'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
    codeController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          actions: [
            IconButton(
              tooltip: 'My Coaches',
              onPressed: _openCoachesSheet,
              icon: const Icon(Icons.groups_2_outlined),
            ),
          ],
          title: const Text('Expert Page'),
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: t.translate('coach_tab_feedback')),
              Tab(text: t.translate('coach_tab_chat')),
              Tab(text: t.translate('coach_tab_form_check')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CoachFeedbackPanel(),
            CoachInfoPanel(
              title: t.translate('coach_tab_chat'),
              icon: Icons.chat_bubble_outline,
              bullets: [
                t.translate('coach_chat_b1'),
                t.translate('coach_chat_b2'),
                t.translate('coach_chat_b3'),
              ],
            ),
            const CoachFormCheckPanel(),
          ],
        ),
      ),
    );
  }
}

class _CoachAssignment {
  const _CoachAssignment({
    required this.id,
    required this.name,
    required this.specialty,
  });

  final int? id;
  final String name;
  final String? specialty;

  String get displayLabel {
    final s = (specialty ?? '').trim();
    if (s.isEmpty) return name;
    return '$name · $s';
  }
}
