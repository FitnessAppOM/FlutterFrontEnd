import 'package:flutter/material.dart';

import '../core/account_storage.dart';
import '../core/user_friendly_error.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/components/taqa_bottom_nav_bar.dart';
import '../TaqaUI/components/taqa_floating_chat_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_steps_ui.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/coach/coach_chat_panel.dart';
import '../widgets/coach/coach_feedback_panel.dart';
import '../widgets/coach/coach_form_check_panel.dart';
import '../widgets/confirm_dialog.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({
    super.key,
    this.initialTabIndex = 0,
    this.initialCoachUserId,
  });

  final int initialTabIndex;
  final int? initialCoachUserId;

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  List<_CoachAssignment> _assignedCoaches = const [];
  List<_CoachConnectionRequest> _coachRequests = const [];
  bool _profileLoaded = false;
  int _coachPanelsRevision = 0;
  final Set<int> _detachingCoachIds = <int>{};
  final Set<int> _reportingCoachIds = <int>{};

  // Chat moved from an inline tab to the floating CHAT button, so the
  // panel index only covers Feedback (0) and Form Check (1) now. The old
  // tab index scheme (0=feedback, 1=chat, 2=form check) is still used by
  // deep links (push notifications), so index 1 opens the chat page
  // directly instead of selecting a tab, and 2 maps to the new index 1.
  late int _panelIndex = widget.initialTabIndex == 2 ? 1 : 0;
  bool _autoOpenedChat = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _autoOpenedChat) return;
        _autoOpenedChat = true;
        _openChatPage();
      });
    }
  }

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
      final requests = _parseCoachRequests(profile);
      if (!mounted) return;
      setState(() {
        _assignedCoaches = coaches;
        _coachRequests = requests;
        _coachPanelsRevision++;
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

  String _resolveCoachName(Map<String, dynamic> map) {
    final direct = (map['name'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final first = (map['first_name'] ?? '').toString().trim();
    final last = (map['last_name'] ?? '').toString().trim();
    final full = (map['full_name'] ?? '').toString().trim();
    final username = (map['username'] ?? '').toString().trim();
    final email = (map['email'] ?? '').toString().trim();

    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    if (last.isNotEmpty) return last;
    if (full.isNotEmpty) return full;
    if (username.isNotEmpty) return username;
    if (email.isNotEmpty) return email;
    return '';
  }

  List<_CoachAssignment> _parseAssignedCoaches(Map<String, dynamic> profile) {
    final coaches = <_CoachAssignment>[];
    final rawExperts = profile['assigned_experts'];
    if (rawExperts is List) {
      for (final item in rawExperts) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final name = _resolveCoachName(map);
        if (name.isEmpty) continue;
        final specialty = _formatSpecialtyLabel(
          (map['specialty'] ?? '').toString().trim(),
        );
        coaches.add(
          _CoachAssignment(
            id:
                _parseInt(map['id']) ??
                _parseInt(map['user_id']) ??
                _parseInt(map['expert_user_id']),
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

  List<_CoachConnectionRequest> _parseCoachRequests(
    Map<String, dynamic> profile,
  ) {
    final requests = <_CoachConnectionRequest>[];
    final rawRequests = profile['coach_connection_requests'];
    if (rawRequests is! List) return const [];
    for (final item in rawRequests) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final coachName = (map['coach_name'] ?? map['name'] ?? '')
          .toString()
          .trim();
      if (coachName.isEmpty) continue;
      final status = (map['status'] ?? '').toString().trim().toLowerCase();
      if (status != 'pending' && status != 'denied') continue;
      requests.add(
        _CoachConnectionRequest(
          coachName: coachName,
          specialty: _formatSpecialtyLabel((map['specialty'] ?? '').toString()),
          status: status,
          updatedAt: (map['updated_at'] ?? map['requested_at'] ?? '')
              .toString()
              .trim(),
        ),
      );
    }
    return requests;
  }

  String _firstNameOnly(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return 'Coach';
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 'Coach';
    return tokens.first;
  }

  Future<String?> _promptReportReason({required String targetName}) async {
    final controller = TextEditingController();
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            'Report Coach',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting $targetName?',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write the reason...',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() => errorText = 'Reason is required.');
                  return;
                }
                Navigator.of(ctx).pop(reason);
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
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

    final coachFirstName = _firstNameOnly(coach.name);
    final confirm = await showConfirmDialog(
      context: context,
      title: "Detach Coach",
      message: "Detach from $coachFirstName?",
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
        "Detached from $coachFirstName.",
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not detach coach. Please try again.',
        ),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _detachingCoachIds.remove(coachId));
      }
    }
  }

  Future<void> _reportCoach(_CoachAssignment coach) async {
    final coachId = coach.id;
    if (coachId == null || coachId <= 0) {
      AppToast.show(
        context,
        "This coach cannot be reported right now.",
        type: AppToastType.error,
      );
      return;
    }
    if (_reportingCoachIds.contains(coachId)) return;

    final coachFirstName = _firstNameOnly(coach.name);
    final reason = await _promptReportReason(targetName: coachFirstName);
    if (reason == null) return;

    setState(() => _reportingCoachIds.add(coachId));
    try {
      await ProfileApi.reportCoach(expertUserId: coachId, reason: reason);
      if (!mounted) return;
      AppToast.show(
        context,
        "Report submitted. Our team will review it.",
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not submit report. Please try again.',
        ),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _reportingCoachIds.remove(coachId));
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
      final status = (result['status'] ?? '').toString().trim().toLowerCase();
      final alreadyConnected = result['already_connected'] == true;
      final alreadyRequested = result['already_requested'] == true;
      AppToast.show(
        context,
        alreadyConnected
            ? "Already connected to $name."
            : alreadyRequested
            ? "Request to $name is already pending."
            : status == 'pending'
            ? "Request sent to $name. Waiting for coach approval."
            : "Connected to $name.",
        type: alreadyConnected
            ? AppToastType.info
            : alreadyRequested
            ? AppToastType.info
            : status == 'pending'
            ? AppToastType.info
            : AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        userFriendlyErrorMessage(
          e,
          fallback: 'Could not connect to coach. Please try again.',
        ),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _openCoachesSheet() async {
    final coaches = List<_CoachAssignment>.from(_assignedCoaches);
    final requests = List<_CoachConnectionRequest>.from(_coachRequests);
    final codeController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_2_outlined,
                        color: Colors.white70,
                      ),
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
                      final isReporting =
                          coachId != null &&
                          coachId > 0 &&
                          _reportingCoachIds.contains(coachId);
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    (coachId == null ||
                                        coachId <= 0 ||
                                        isDetaching ||
                                        isReporting)
                                    ? null
                                    : () async {
                                        Navigator.of(sheetContext).pop();
                                        await _reportCoach(coach);
                                      },
                                icon: isReporting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.orangeAccent,
                                        ),
                                      )
                                    : const Icon(Icons.flag_outlined, size: 18),
                                label: const Text('Report'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed:
                                    (coachId == null ||
                                        coachId <= 0 ||
                                        isDetaching ||
                                        isReporting)
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
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    : const Icon(Icons.link_off, size: 18),
                                label: const Text('Detach'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (requests.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Connection Requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...requests.map((request) {
                      final isPending = request.status == 'pending';
                      final updatedDate = request.updatedAt.contains('T')
                          ? request.updatedAt.split('T').first
                          : request.updatedAt;
                      final statusLine = isPending
                          ? 'Pending approval${updatedDate.isEmpty ? '' : ' · $updatedDate'}'
                          : 'Request denied${updatedDate.isEmpty ? '' : ' · $updatedDate'}';
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
                          leading: Icon(
                            isPending
                                ? Icons.hourglass_top_rounded
                                : Icons.cancel_outlined,
                            color: isPending
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                          ),
                          title: Text(
                            request.coachName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            statusLine,
                            style: TextStyle(
                              color: isPending
                                  ? Colors.orangeAccent
                                  : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                          trailing: (request.specialty ?? '').isEmpty
                              ? null
                              : Text(
                                  request.specialty!,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    codeController.dispose();
  }

  Future<void> _openChatPage() async {
    final chatTitle = AppLocalizations.of(context).translate('coach_tab_chat');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
          appBar: TaqaPageAppBar(title: chatTitle),
          body: SafeArea(
            child: CoachChatPanel(initialCoachUserId: widget.initialCoachUserId),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        title: 'Expert Dashboard',
        trailing: IconButton(
          tooltip: 'My Coaches',
          onPressed: _openCoachesSheet,
          icon: Icon(
            Icons.groups_2_outlined,
            color: TaqaUiColors.unnamedColor1c1d17,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: TaqaUiScale.insetsLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TaqaRangeTab(
                      label: t.translate('coach_tab_feedback'),
                      selected: _panelIndex == 0,
                      onTap: () => setState(() => _panelIndex = 0),
                    ),
                  ),
                  SizedBox(width: TaqaUiScale.w(15)),
                  Expanded(
                    child: TaqaRangeTab(
                      label: t.translate('coach_tab_form_check'),
                      selected: _panelIndex == 1,
                      onTap: () => setState(() => _panelIndex = 1),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _panelIndex,
                children: [
                  CoachFeedbackPanel(
                    key: ValueKey('coach_feedback_$_coachPanelsRevision'),
                  ),
                  CoachFormCheckPanel(
                    key: ValueKey('coach_form_check_$_coachPanelsRevision'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Placing the nav bar here (rather than inside body) is what makes the
      // Scaffold dock the floating chat button above it automatically,
      // instead of the two overlapping.
      bottomNavigationBar: TaqaBottomNavBar(
        currentIndex: 4,
        onTap: (index) {
          if (index == 4) return;
          Navigator.of(context).pop();
        },
        items: const [
          TaqaBottomNavItem(assetPath: 'assets/icons/Diet.svg', index: 0),
          TaqaBottomNavItem(assetPath: 'assets/icons/Exercise.svg', index: 1),
          TaqaBottomNavItem(assetPath: 'assets/icons/Home.svg', index: 2),
          TaqaBottomNavItem(
            assetPath: 'assets/icons/Community.svg',
            index: 3,
          ),
          TaqaBottomNavItem(assetPath: 'assets/icons/Trainer.svg', index: 4),
        ],
      ),
      floatingActionButton: TaqaFloatingChatButton(onTap: _openChatPage),
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

class _CoachConnectionRequest {
  const _CoachConnectionRequest({
    required this.coachName,
    required this.specialty,
    required this.status,
    required this.updatedAt,
  });

  final String coachName;
  final String? specialty;
  final String status;
  final String updatedAt;
}
