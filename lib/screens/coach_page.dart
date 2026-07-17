import 'package:flutter/material.dart';

import '../core/account_storage.dart';
import '../core/user_friendly_error.dart';
import '../localization/app_localizations.dart';
import '../services/auth/profile_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
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
import '../TaqaUI/components/taqa_value_dialog.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({
    super.key,
    this.initialTabIndex = 0,
    this.initialCoachUserId,
    this.showBottomNavigation = true,
  });

  final int initialTabIndex;
  final int? initialCoachUserId;
  final bool showBottomNavigation;

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
    // Not a TextEditingController owned here: see _ReportReasonField for why
    // (disposing a controller right after the dialog's future resolves can
    // race the dialog's still-animating exit transition).
    var reportReasonText = '';
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return MediaQuery.removeViewInsets(
              context: ctx,
              removeBottom: true,
              child: TaqaPopupDialog(
                bottomInset: bottomInset,
                onBackgroundTap: () =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Report Coach',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(15),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.charcoal,
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(8)),
                    Text(
                      'Why are you reporting $targetName?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(14)),
                    _ReportReasonField(
                      errorText: errorText,
                      onChanged: (value) => reportReasonText = value,
                    ),
                    SizedBox(height: TaqaUiScale.h(16)),
                    SizedBox(
                      height: TaqaUiScale.h(45),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: Center(
                                child: Text(
                                  "CANCEL",
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(10),
                                    fontWeight: FontWeight.w600,
                                    color: TaqaUiColors.charcoal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: TaqaUiColors.unnamedColorE4e93b,
                            borderRadius: TaqaUiScale.radius(5),
                            child: InkWell(
                              borderRadius: TaqaUiScale.radius(5),
                              onTap: () {
                                final reason = reportReasonText.trim();
                                if (reason.isEmpty) {
                                  setDialogState(
                                    () => errorText = 'Reason is required.',
                                  );
                                  return;
                                }
                                Navigator.of(ctx).pop(reason);
                              },
                              child: SizedBox(
                                width: TaqaUiScale.w(159),
                                height: TaqaUiScale.h(45),
                                child: Center(
                                  child: Text(
                                    "REPORT",
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      fontSize: TaqaUiScale.sp(10),
                                      fontWeight: FontWeight.w700,
                                      color: TaqaUiColors.charcoal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: "Detach Coach",
      message: "Detach from $coachFirstName?",
      confirmLabel: "Detach",
    );
    if (!confirm) return;

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
      // Reporting a coach implies you no longer want them assigned to you,
      // so detach automatically instead of leaving the (now-reported) coach
      // connected until the client separately remembers to detach.
      try {
        await ProfileApi.detachCoach(expertUserId: coachId);
      } catch (_) {
        // Report already went through; a failed auto-detach shouldn't block
        // that or surface as an error — the client can still detach manually.
      }
      await _loadAssignedCoaches();
      if (!mounted) return;
      AppToast.show(
        context,
        "Report submitted and $coachFirstName has been detached.",
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

      final name = _firstNameOnly((result['name'] ?? 'Coach').toString());
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
    // Owned by _CoachCodeField below, not created here: a TextEditingController
    // created in this method and disposed right after showModalBottomSheet's
    // future resolves can outlive the sheet's still-animating exit transition
    // (pop() resolves the future before the TextField is actually unmounted),
    // throwing "used after being disposed". Tracking the text in a plain
    // closure variable instead avoids owning any controller here.
    var enteredCoachCode = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TaqaUiScale.r(24)),
        ),
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
              padding: TaqaUiScale.insetsLTRB(16, 10, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: TaqaUiScale.w(36),
                      height: TaqaUiScale.h(4),
                      decoration: BoxDecoration(
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.2),
                        borderRadius: TaqaUiScale.radius(99),
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(18)),
                  Text(
                    'MY COACHES',
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                      fontSize: TaqaUiScale.sp(10),
                      fontWeight: FontWeight.w700,
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(14)),
                  _CoachCodeField(
                    onChanged: (value) => enteredCoachCode = value,
                  ),
                  SizedBox(height: TaqaUiScale.h(10)),
                  Material(
                    color: TaqaUiColors.accent,
                    borderRadius: TaqaUiScale.radius(5),
                    child: InkWell(
                      borderRadius: TaqaUiScale.radius(5),
                      onTap: () async {
                        final code = enteredCoachCode.trim();
                        Navigator.of(sheetContext).pop();
                        await _connectCoachByCode(code);
                      },
                      child: Container(
                        height: TaqaUiScale.h(45),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.link,
                              size: TaqaUiScale.w(16),
                              color: TaqaUiColors.charcoal,
                            ),
                            SizedBox(width: TaqaUiScale.w(8)),
                            Text(
                              'CONNECT',
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                fontSize: TaqaUiScale.sp(14),
                                fontWeight: FontWeight.w700,
                                color: TaqaUiColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(18)),
                  if (coaches.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: TaqaUiScale.h(8)),
                      child: Text(
                        'No coaches connected.',
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                          fontSize: TaqaUiScale.sp(13),
                        ),
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
                        margin: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                        padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                SizedBox(width: TaqaUiScale.w(10)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _firstNameOnly(coach.name),
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          color: TaqaUiColors.charcoal,
                                          fontWeight: FontWeight.w700,
                                          fontSize: TaqaUiScale.sp(14),
                                        ),
                                      ),
                                      if ((coach.specialty ?? '')
                                          .isNotEmpty) ...[
                                        SizedBox(height: TaqaUiScale.h(2)),
                                        Text(
                                          coach.specialty!,
                                          style: TextStyle(
                                            fontFamily:
                                                TaqaUiFontFamilies.interTight,
                                            color: TaqaUiColors.charcoal
                                                .withValues(alpha: 0.55),
                                            fontSize: TaqaUiScale.sp(12),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: TaqaUiScale.h(10)),
                            Wrap(
                              spacing: TaqaUiScale.w(8),
                              runSpacing: TaqaUiScale.h(8),
                              children: [
                                _CoachSheetActionChip(
                                  icon: Icons.flag_outlined,
                                  label: 'Report',
                                  loading: isReporting,
                                  onTap:
                                      (coachId == null ||
                                          coachId <= 0 ||
                                          isDetaching ||
                                          isReporting)
                                      ? null
                                      : () async {
                                          Navigator.of(sheetContext).pop();
                                          await _reportCoach(coach);
                                        },
                                ),
                                _CoachSheetActionChip(
                                  icon: Icons.link_off,
                                  label: 'Detach',
                                  loading: isDetaching,
                                  onTap:
                                      (coachId == null ||
                                          coachId <= 0 ||
                                          isDetaching ||
                                          isReporting)
                                      ? null
                                      : () async {
                                          Navigator.of(sheetContext).pop();
                                          await _detachCoach(coach);
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  if (requests.isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(6)),
                    Text(
                      'CONNECTION REQUESTS',
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                        fontSize: TaqaUiScale.sp(10),
                        fontWeight: FontWeight.w700,
                        color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
                      ),
                    ),
                    SizedBox(height: TaqaUiScale.h(10)),
                    ...requests.map((request) {
                      final isPending = request.status == 'pending';
                      final updatedDate = request.updatedAt.contains('T')
                          ? request.updatedAt.split('T').first
                          : request.updatedAt;
                      final statusLine = isPending
                          ? 'Pending approval${updatedDate.isEmpty ? '' : ' · $updatedDate'}'
                          : 'Request denied${updatedDate.isEmpty ? '' : ' · $updatedDate'}';
                      final statusColor = isPending
                          ? const Color(0xFFFF8A00)
                          : const Color(0xFFE84C4F);
                      return Container(
                        margin: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                        padding: TaqaUiScale.insetsLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPending
                                  ? Icons.hourglass_top_rounded
                                  : Icons.cancel_outlined,
                              color: statusColor,
                            ),
                            SizedBox(width: TaqaUiScale.w(10)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _firstNameOnly(request.coachName),
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      color: TaqaUiColors.charcoal,
                                      fontWeight: FontWeight.w700,
                                      fontSize: TaqaUiScale.sp(14),
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(2)),
                                  Text(
                                    statusLine,
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      color: statusColor,
                                      fontSize: TaqaUiScale.sp(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if ((request.specialty ?? '').isNotEmpty)
                              Text(
                                request.specialty!,
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.55,
                                  ),
                                  fontSize: TaqaUiScale.sp(12),
                                ),
                              ),
                          ],
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
  }

  Future<void> _openChatPage() async {
    final chatTitle = AppLocalizations.of(context).translate('coach_tab_chat');
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
          appBar: TaqaPageAppBar(title: chatTitle),
          body: SafeArea(
            child: CoachChatPanel(
              initialCoachUserId: widget.initialCoachUserId,
            ),
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
            SizedBox(height: TaqaUiScale.h(16)),
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
      // MainLayout already provides the persistent app navigation when this
      // page is rendered as its Coach tab. Standalone deep links retain a bar.
      bottomNavigationBar: widget.showBottomNavigation
          ? TaqaBottomNavBar(
              currentIndex: 4,
              onTap: (index) {
                if (index == 4) return;
                Navigator.of(context).pop();
              },
              items: const [
                TaqaBottomNavItem(assetPath: 'assets/icons/Diet.svg', index: 0),
                TaqaBottomNavItem(
                  assetPath: 'assets/icons/Exercise.svg',
                  index: 1,
                ),
                TaqaBottomNavItem(assetPath: 'assets/icons/Home.svg', index: 2),
                TaqaBottomNavItem(
                  assetPath: 'assets/icons/Community.svg',
                  index: 3,
                ),
                TaqaBottomNavItem(
                  assetPath: 'assets/icons/Trainer.svg',
                  index: 4,
                ),
              ],
            )
          : null,
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

class _CoachSheetActionChip extends StatelessWidget {
  const _CoachSheetActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = TaqaUiColors.charcoal.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: TaqaUiScale.radius(999),
      child: Container(
        padding: TaqaUiScale.insetsLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: TaqaUiColors.unnamedColorE3e3e3,
          borderRadius: TaqaUiScale.radius(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: TaqaUiScale.w(14),
                height: TaqaUiScale.w(14),
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: TaqaUiScale.w(16), color: color),
            SizedBox(width: TaqaUiScale.w(6)),
            Text(
              label,
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                color: color,
                fontSize: TaqaUiScale.sp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its own [TextEditingController] so disposal is tied to this widget's
/// actual unmount (after the bottom sheet's exit animation finishes) rather
/// than to when the enclosing showModalBottomSheet future resolves — see the
/// comment in _openCoachesSheet for why that distinction matters.
class _CoachCodeField extends StatefulWidget {
  const _CoachCodeField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_CoachCodeField> createState() => _CoachCodeFieldState();
}

class _CoachCodeFieldState extends State<_CoachCodeField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        color: TaqaUiColors.charcoal,
      ),
      decoration: InputDecoration(
        counterText: "",
        hintText: "Enter 6-digit coach code",
        hintStyle: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          color: TaqaUiColors.charcoal.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: TaqaUiColors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: BorderSide(
            color: TaqaUiColors.charcoal.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

/// Owns its own [TextEditingController], same reasoning as _CoachCodeField:
/// disposing a controller right after the dialog's showDialog future
/// resolves can race the dialog's still-animating exit transition.
class _ReportReasonField extends StatefulWidget {
  const _ReportReasonField({required this.errorText, required this.onChanged});

  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  State<_ReportReasonField> createState() => _ReportReasonFieldState();
}

class _ReportReasonFieldState extends State<_ReportReasonField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: 1000,
      minLines: 3,
      maxLines: 6,
      autofocus: true,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        color: TaqaUiColors.charcoal,
      ),
      decoration: InputDecoration(
        hintText: 'Write the reason...',
        hintStyle: TextStyle(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.4),
        ),
        errorText: widget.errorText,
        filled: true,
        fillColor: TaqaUiColors.unnamedColorE3e3e3,
        enabledBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TaqaUiScale.radius(10),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
