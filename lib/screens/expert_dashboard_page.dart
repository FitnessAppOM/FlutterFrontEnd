import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/base_url.dart';
import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/diet_document_file_service.dart';
import '../services/core/pdf_open_service.dart';
import '../services/coach/progression_review_service.dart';
import '../services/core/navigation_service.dart';
import '../services/training/training_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_empty_state_row.dart';
import '../TaqaUI/components/taqa_exercise_picker_sheet.dart';
import '../TaqaUI/components/taqa_expert_dashboard_ui.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_pill_tab.dart';
import '../TaqaUI/components/taqa_program_template_sheets.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import 'expert_client_detail_page.dart';
import 'expert_connection_requests_page.dart';
import 'expert_progression_review_page.dart';
import 'expert_plan_template_create_page.dart';

String? _normalizeAvatarUrlForUi(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  if (lower == 'null' || lower == 'none') return null;
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return raw;
  }
  final base = ApiConfig.baseUrl.trim();
  if (base.isEmpty) return null;
  try {
    final baseUri = Uri.parse(base.endsWith('/') ? base : '$base/');
    return baseUri.resolve(raw).toString();
  } catch (_) {
    return null;
  }
}

class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  static const int _tabMyClients = 0;
  static const int _tabPrograms = 1;
  static const int _tabNutrition = 2;

  int _tabIndex = _tabMyClients;
  bool _loading = true;
  bool _generating = false;
  List<ProgressionClient> _clients = const [];
  List<ProgressionReview> _reviews = const [];
  List<Map<String, dynamic>> _planTemplates = const [];
  List<CoachDietDocument> _nutritionDocuments = const [];
  final Set<int> _pinningNutritionDocumentIds = <int>{};
  final Set<int> _deletingNutritionDocumentIds = <int>{};
  final Set<int> _openingNutritionDocumentIds = <int>{};
  final Set<int> _assigningPlanTemplateIds = <int>{};
  final Set<int> _deletingPlanTemplateIds = <int>{};
  int _newPendingConnectionRequestCount = 0;
  final Set<int> _dietBadgeSuppressedClientIds = <int>{};
  final Set<int> _newClientBadgeSuppressedClientIds = <int>{};
  final Set<int> _supportChatUnreadClientIds = <int>{};
  int _supportChatUnreadRefreshSequence = 0;
  bool _openingPlanCreator = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService.setNotificationNavigationReady(true);
      NavigationService.flushPendingNotificationNavigation();
    });
    _load();
  }

  String _clientDisplayName(ProgressionClient client) {
    final raw = (client.name ?? '').trim();
    if (raw.isNotEmpty) return raw;
    return 'Client #${client.userId}';
  }

  List<String> _clientAlerts(
    ProgressionClient client, {
    required bool hasSupportChatUnread,
  }) {
    final alerts = <String>[];
    if (client.hasNewAssignment) {
      alerts.add(
        client.newAssignmentCount > 1
            ? 'New client assignments (${client.newAssignmentCount})'
            : 'New client assignment',
      );
    }
    if (client.hasDietLogToReview) {
      alerts.add(
        client.sharedDietLogCount > 1
            ? 'New diet logs (${client.sharedDietLogCount})'
            : 'New diet log',
      );
    }
    if (hasSupportChatUnread) alerts.add('New support chat message');
    final hasForm = client.hasFormCheckToReview;
    final hasTraining = client.hasUncheckedTrainingPlan;
    if (hasForm && hasTraining) {
      final total =
          client.sharedFormCheckCount + client.trainingPlanUncheckedCount;
      alerts.add(
        total > 1
            ? 'AI updates pending review ($total)'
            : 'AI update pending review',
      );
    } else if (hasForm) {
      alerts.add(
        client.sharedFormCheckCount > 1
            ? 'AI updates: form checks awaiting reply (${client.sharedFormCheckCount})'
            : 'AI updates: form check awaiting reply',
      );
    } else if (hasTraining) {
      alerts.add(
        client.trainingPlanUncheckedCount > 1
            ? 'AI updates: training plans pending verification (${client.trainingPlanUncheckedCount})'
            : 'AI updates: training plan pending verification',
      );
    }
    return alerts;
  }

  Future<void> _openPlanCreatorSheet() async {
    if (_openingPlanCreator) return;
    setState(() => _openingPlanCreator = true);
    try {
      final libraryExercises = <ExercisePickerItem>[];
      final raw = await TrainingService.fetchAllExercises();
      for (final item in raw) {
        if (item is! Map) continue;
        final exerciseId = int.tryParse((item['exercise_id'] ?? '').toString());
        final name = (item['exercise_name'] ?? '').toString().trim();
        if (exerciseId == null || exerciseId <= 0 || name.isEmpty) continue;
        libraryExercises.add(ExercisePickerItem(id: exerciseId, name: name));
      }
      libraryExercises.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      if (!mounted) return;
      if (libraryExercises.isEmpty) {
        AppToast.show(
          context,
          'Exercise library is empty or unavailable.',
          type: AppToastType.error,
        );
        return;
      }

      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) =>
              ExpertPlanTemplateCreatePage(exerciseLibrary: libraryExercises),
        ),
      );
      if (!mounted || result == null) return;
      final templateId = (result['template_id'] ?? '').toString();
      AppToast.show(
        context,
        templateId.isNotEmpty
            ? 'Template saved (#$templateId).'
            : 'Template saved.',
        type: AppToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _openingPlanCreator = false);
    }
  }

  Future<void> _openAssignTemplateSheet(Map<String, dynamic> template) async {
    if (_clients.isEmpty) {
      AppToast.show(
        context,
        'No assigned clients yet.',
        type: AppToastType.info,
      );
      return;
    }
    final templateId = int.tryParse('${template['template_id'] ?? ''}') ?? 0;
    if (templateId <= 0 || _assigningPlanTemplateIds.contains(templateId)) {
      return;
    }
    final templateTitle = (template['title'] ?? '').toString().trim();
    final currentAssignedClientIdsRaw =
        template['currently_assigned_client_ids'];
    final currentAssignedClientIds = currentAssignedClientIdsRaw is List
        ? currentAssignedClientIdsRaw
              .map((value) => int.tryParse('$value'))
              .whereType<int>()
              .toSet()
        : <int>{};
    final sortedClients = [..._clients]
      ..sort(
        (a, b) => _clientDisplayName(
          a,
        ).toLowerCase().compareTo(_clientDisplayName(b).toLowerCase()),
      );
    final assignment = await showTaqaTemplateAssignSheet(
      context: context,
      templateTitle: templateTitle,
      clients: sortedClients
          .map(
            (client) => TaqaTemplateAssignClient(
              id: client.userId,
              name: _clientDisplayName(client),
              avatarUrl: _normalizeAvatarUrlForUi(client.avatarUrl),
              status: client.activityStatus,
              currentlyAssigned: currentAssignedClientIds.contains(
                client.userId,
              ),
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || assignment == null) return;

    setState(() => _assigningPlanTemplateIds.add(templateId));
    try {
      var assignedCount = 0;
      final failures = <String>[];
      for (final clientId in assignment.clientIds) {
        try {
          await ProgressionReviewService.assignPlanTemplateToClient(
            templateId: templateId,
            clientUserId: clientId,
            archiveExisting: true,
          );
          assignedCount += 1;
        } catch (error) {
          failures.add(error.toString().replaceFirst('Exception: ', ''));
        }
      }
      if (assignedCount > 0) {
        await _load();
      }
      if (!mounted) return;
      if (failures.isEmpty) {
        AppToast.show(
          context,
          assignedCount == 1
              ? 'Assigned to 1 client.'
              : 'Assigned to $assignedCount clients.',
          type: AppToastType.success,
        );
      } else if (assignedCount > 0) {
        AppToast.show(
          context,
          'Assigned to $assignedCount; ${failures.length} could not be assigned.',
          type: AppToastType.info,
        );
      } else {
        AppToast.show(
          context,
          failures.length == 1
              ? failures.first
              : 'No selected clients could be assigned.',
          type: AppToastType.error,
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _assigningPlanTemplateIds.remove(templateId));
      }
    }
  }

  Future<void> _deletePlanTemplate(Map<String, dynamic> template) async {
    final templateId = int.tryParse('${template['template_id'] ?? ''}') ?? 0;
    if (templateId <= 0 || _deletingPlanTemplateIds.contains(templateId)) {
      return;
    }
    final title = (template['title'] ?? '').toString().trim();
    final confirmed = await showTaqaConfirmDialog(
      context: context,
      title: 'Delete template?',
      message: title.isEmpty
          ? 'Are you sure you want to delete this template?'
          : 'Are you sure you want to delete "$title"?',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );
    if (!confirmed) return;

    setState(() => _deletingPlanTemplateIds.add(templateId));
    try {
      await ProgressionReviewService.deletePlanTemplate(templateId: templateId);
      if (!mounted) return;
      setState(() {
        _planTemplates = _planTemplates
            .where(
              (item) =>
                  (int.tryParse('${item['template_id'] ?? ''}') ?? 0) !=
                  templateId,
            )
            .toList(growable: false);
      });
      AppToast.show(context, 'Template deleted.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _deletingPlanTemplateIds.remove(templateId));
      }
    }
  }

  String? _avatarFromKnownClients(int userId) {
    for (final client in _clients) {
      if (client.userId == userId) {
        final normalized = _normalizeAvatarUrlForUi(client.avatarUrl);
        if ((normalized ?? '').isNotEmpty) return normalized;
        break;
      }
    }
    return null;
  }

  String? _statusFromKnownClients(int userId) {
    for (final client in _clients) {
      if (client.userId == userId) return client.activityStatus;
    }
    return null;
  }

  Map<String, dynamic> _enrichAssignedClientAvatar(Map<String, dynamic> item) {
    final userId = int.tryParse('${item['user_id'] ?? ''}') ?? 0;
    final cachedAvatar = userId > 0 ? _avatarFromKnownClients(userId) : null;
    final rawAvatar = _normalizeAvatarUrlForUi(item['avatar_url']);
    final resolvedAvatar = (cachedAvatar ?? '').isNotEmpty
        ? cachedAvatar
        : rawAvatar;
    return {
      ...item,
      'avatar_url': resolvedAvatar,
      'activity_status': _statusFromKnownClients(userId),
    };
  }

  List<Map<String, dynamic>> _enrichAssignedClientsAvatar(
    List<Map<String, dynamic>> items,
  ) {
    return items.map(_enrichAssignedClientAvatar).toList(growable: false);
  }

  Future<void> _openAssignedClientsSheet(
    String templateTitle,
    List<Map<String, dynamic>> assignedClients,
  ) async {
    final resolvedAssignedClients = _enrichAssignedClientsAvatar(
      assignedClients,
    );
    if (resolvedAssignedClients.isEmpty) return;
    await showTaqaTemplateAssignedClientsSheet(
      context: context,
      templateTitle: templateTitle,
      clients: resolvedAssignedClients
          .map((item) {
            final userId = int.tryParse('${item['user_id'] ?? ''}') ?? 0;
            final rawName = (item['name'] ?? '').toString().trim();
            final avatarUrl = (item['avatar_url'] ?? '').toString().trim();
            return TaqaTemplateAssignClient(
              id: userId,
              name: rawName.isEmpty ? 'Client #$userId' : rawName,
              avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
              status: (item['activity_status'] ?? '').toString().trim(),
              currentlyAssigned: true,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _openTemplatePreviewSheet(Map<String, dynamic> template) async {
    final title = (template['title'] ?? '').toString().trim();
    final daysRaw = template['days'];
    final rawDays = daysRaw is List
        ? daysRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final days = rawDays
        .asMap()
        .entries
        .map((entry) {
          final day = entry.value;
          final parsedNumber = int.tryParse('${day['day_index'] ?? ''}');
          final dayNumber = parsedNumber != null && parsedNumber > 0
              ? parsedNumber
              : entry.key + 1;
          final dayLabel = (day['day_label'] ?? '').toString().trim();
          final exercisesRaw = day['exercises'];
          final exercises = exercisesRaw is List
              ? exercisesRaw
                    .whereType<Map>()
                    .map((rawExercise) {
                      final exercise = Map<String, dynamic>.from(rawExercise);
                      final name = (exercise['exercise_name'] ?? '')
                          .toString()
                          .trim();
                      final sets = int.tryParse('${exercise['sets'] ?? ''}');
                      final reps = int.tryParse('${exercise['reps'] ?? ''}');
                      final rir = int.tryParse('${exercise['rir'] ?? ''}');
                      final weight = double.tryParse(
                        '${exercise['weight_kg'] ?? ''}',
                      );
                      final weightLabel = weight == null
                          ? '-'
                          : weight == weight.roundToDouble()
                          ? '${weight.toInt()} kg'
                          : '${weight.toStringAsFixed(1)} kg';
                      return TaqaTemplatePreviewExercise(
                        name: name.isEmpty ? 'Exercise' : name,
                        sets: sets == null || sets <= 0 ? '-' : '$sets',
                        reps: reps == null || reps <= 0 ? '-' : '$reps',
                        rir: rir == null ? '-' : '$rir',
                        weight: weightLabel,
                      );
                    })
                    .toList(growable: false)
              : const <TaqaTemplatePreviewExercise>[];
          return TaqaTemplatePreviewDay(
            number: dayNumber,
            label: dayLabel.isEmpty ? 'Day $dayNumber' : dayLabel,
            exercises: exercises,
          );
        })
        .toList(growable: false);

    await showTaqaTemplatePreviewSheet(
      context: context,
      title: title,
      days: days,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final previousNewClientCount = _clients
        .where(
          (client) =>
              client.hasNewAssignment &&
              !_newClientBadgeSuppressedClientIds.contains(client.userId),
        )
        .length;
    final previousNewRequestCount = _newPendingConnectionRequestCount;
    try {
      final results = await Future.wait([
        ProgressionReviewService.fetchClients(),
        ProgressionReviewService.fetchReviews(includeApplied: true),
        ProgressionReviewService.fetchPendingConnectionRequests(),
        ProgressionReviewService.fetchPlanTemplates(),
        ProgressionReviewService.fetchAssignedDietDocuments(),
      ]);
      final fetchedClients = results[0] as List<ProgressionClient>;
      final fetchedReviews = results[1] as List<ProgressionReview>;
      final requestSummary = results[2] as CoachConnectionRequestSummary;
      final fetchedPlanTemplates = results[3] as List<Map<String, dynamic>>;
      final fetchedNutritionDocuments = results[4] as List<CoachDietDocument>;
      final visibleNewClientCount = fetchedClients
          .where(
            (client) =>
                client.hasNewAssignment &&
                !_newClientBadgeSuppressedClientIds.contains(client.userId),
          )
          .length;
      if (!mounted) return;
      setState(() {
        _clients = fetchedClients;
        _reviews = fetchedReviews;
        _planTemplates = fetchedPlanTemplates;
        _nutritionDocuments = fetchedNutritionDocuments;
        _newPendingConnectionRequestCount = requestSummary.newPendingCount;
        _dietBadgeSuppressedClientIds.removeWhere((userId) {
          final matched = _clients.where((c) => c.userId == userId);
          if (matched.isEmpty) return true;
          // Keep local suppression only while backend also says "no new diet logs".
          // If backend reports new logs again, restore the outside badge.
          return matched.any(
            (c) => c.hasDietLogToReview || c.sharedDietLogCount > 0,
          );
        });
        _newClientBadgeSuppressedClientIds.removeWhere((userId) {
          final matched = _clients.where((c) => c.userId == userId);
          if (matched.isEmpty) return true;
          // Keep local suppression only while backend also says "assignment seen".
          // If backend reports new assignment again, restore outside marker.
          return matched.any(
            (c) => c.hasNewAssignment || c.newAssignmentCount > 0,
          );
        });
        _supportChatUnreadClientIds.removeWhere(
          (userId) => !_clients.any((client) => client.userId == userId),
        );
      });
      unawaited(_refreshSupportChatUnreadFlags(fetchedClients));
      if (visibleNewClientCount > previousNewClientCount) {
        AppToast.show(
          context,
          visibleNewClientCount == 1
              ? 'You have 1 new assigned client.'
              : 'You have $visibleNewClientCount new assigned clients.',
          type: AppToastType.info,
        );
      }
      if (_newPendingConnectionRequestCount > previousNewRequestCount) {
        AppToast.show(
          context,
          _newPendingConnectionRequestCount == 1
              ? 'You have 1 new connection request.'
              : 'You have $_newPendingConnectionRequestCount new connection requests.',
          type: AppToastType.info,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSupportChatUnreadFlags(
    List<ProgressionClient> clients,
  ) async {
    final refreshSequence = ++_supportChatUnreadRefreshSequence;
    if (clients.isEmpty) {
      if (!mounted) return;
      setState(() => _supportChatUnreadClientIds.clear());
      return;
    }
    final unreadEntries = await Future.wait(
      clients.map((client) async {
        try {
          final hasUnread =
              await CoachSupportChatService.fetchCoachClientThreadHasUnread(
                clientUserId: client.userId,
              );
          return MapEntry(client.userId, hasUnread);
        } catch (_) {
          return MapEntry(client.userId, false);
        }
      }),
    );
    if (!mounted || refreshSequence != _supportChatUnreadRefreshSequence) {
      return;
    }
    final unreadClientIds = unreadEntries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    setState(() {
      _supportChatUnreadClientIds
        ..clear()
        ..addAll(unreadClientIds);
    });
  }

  Future<void> _generateReview(int clientUserId, {required bool force}) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final result = await ProgressionReviewService.generateReview(
        clientUserId,
        force: force,
      );
      if (!mounted) return;
      final status = (result['status'] ?? '').toString();
      String message;
      switch (status) {
        case 'generated':
          message = 'AI update review generated.';
          break;
        case 'exists':
          message = 'A review already exists for this week.';
          break;
        case 'noop':
          message =
              (result['detail'] ?? result['reason'] ?? 'No review generated.')
                  .toString();
          break;
        case 'failed':
          message =
              (result['detail'] ?? result['reason'] ?? 'Generation failed.')
                  .toString();
          break;
        default:
          message = result.toString();
      }
      AppToast.show(
        context,
        message,
        type: status == 'generated' || status == 'exists'
            ? AppToastType.success
            : AppToastType.info,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openReview(ProgressionReview review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertProgressionReviewPage(reviewId: review.reviewId),
      ),
    );
    await _load();
  }

  Future<void> _openConnectionRequests() async {
    if (_newPendingConnectionRequestCount > 0) {
      setState(() {
        _newPendingConnectionRequestCount = 0;
      });
      unawaited(
        ProgressionReviewService.markConnectionRequestsSeen().catchError((_) {
          // Keep UX smooth even if marking seen fails; next refresh restores state.
        }),
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExpertConnectionRequestsPage()),
    );
    await _load();
  }

  Future<void> _openClientDetail(ProgressionClient client) async {
    final hasVisibleNewAssignment =
        client.hasNewAssignment &&
        !_newClientBadgeSuppressedClientIds.contains(client.userId);
    if (hasVisibleNewAssignment) {
      setState(() {
        _newClientBadgeSuppressedClientIds.add(client.userId);
      });
      unawaited(
        ProgressionReviewService.markClientAssignmentSeen(
          clientUserId: client.userId,
        ).catchError((_) {
          if (!mounted) return;
          setState(() {
            _newClientBadgeSuppressedClientIds.remove(client.userId);
          });
        }),
      );
    }
    final clientReviews = _reviews
        .where((review) => review.userId == client.userId)
        .toList();
    final detached = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpertClientDetailPage(
          client: client,
          reviews: clientReviews,
          onDietLogSeen: () {
            if (!mounted) return;
            setState(() {
              _dietBadgeSuppressedClientIds.add(client.userId);
            });
          },
        ),
      ),
    );
    if (detached == true && mounted) {
      AppToast.show(context, 'Client detached.', type: AppToastType.success);
    }
    await _load();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$mm/$dd ${local.year} $hh:$min';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _openNutritionDocument(CoachDietDocument document) async {
    if (_openingNutritionDocumentIds.contains(document.documentId)) return;
    setState(() => _openingNutritionDocumentIds.add(document.documentId));
    try {
      final url = (document.documentUrl ?? '').trim();
      if (url.isEmpty) {
        throw Exception('Document URL is missing.');
      }
      final suggestedFileName =
          document.originalFilename ?? document.documentTitle;
      final localPath =
          await DietDocumentFileService.prepareLocalDietDocumentFile(
            url,
            suggestedFileName: suggestedFileName,
          );
      // PDFs stay in-app via the same viewer used for announcements/diet
      // plans/chat attachments; other document types (doc/docx/txt/rtf)
      // still need an external app that can render them.
      if (PdfOpenService.isPdfUrl(url, suggestedFileName: suggestedFileName) ||
          localPath.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        await PdfOpenService.openLocalFile(
          context,
          path: localPath,
          title: document.documentTitle ?? suggestedFileName ?? 'Document',
        );
        return;
      }

      var opened = false;
      try {
        opened = await launchUrl(
          Uri.file(localPath),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
      if (!opened) {
        final remoteUri = DietDocumentFileService.resolveUri(url);
        if (remoteUri != null) {
          opened = await launchUrl(
            remoteUri,
            mode: LaunchMode.externalApplication,
          );
        }
      }
      if (!opened) {
        throw Exception('Could not open downloaded document on this device.');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(
          () => _openingNutritionDocumentIds.remove(document.documentId),
        );
      }
    }
  }

  Future<void> _toggleNutritionDocumentPin(CoachDietDocument document) async {
    if (_pinningNutritionDocumentIds.contains(document.documentId)) return;
    setState(() => _pinningNutritionDocumentIds.add(document.documentId));
    try {
      final updated =
          await ProgressionReviewService.setClientDietDocumentPinned(
            clientUserId: document.clientUserId,
            documentId: document.documentId,
            isPinned: !document.isPinned,
          );
      if (!mounted) return;
      setState(() {
        _nutritionDocuments = _nutritionDocuments
            .map(
              (item) => item.documentId == updated.documentId ? updated : item,
            )
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(
          () => _pinningNutritionDocumentIds.remove(document.documentId),
        );
      }
    }
  }

  Future<void> _deleteNutritionDocument(CoachDietDocument document) async {
    if (_deletingNutritionDocumentIds.contains(document.documentId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plan document?'),
        content: const Text('This will remove it for the client and coach.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingNutritionDocumentIds.add(document.documentId));
    try {
      await ProgressionReviewService.deleteClientDietDocument(
        clientUserId: document.clientUserId,
        documentId: document.documentId,
      );
      if (!mounted) return;
      setState(() {
        _nutritionDocuments = _nutritionDocuments
            .where((item) => item.documentId != document.documentId)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(
          () => _deletingNutritionDocumentIds.remove(document.documentId),
        );
      }
    }
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
  }

  Widget _buildInboxButton() {
    final hasPending = _newPendingConnectionRequestCount > 0;
    final accent = const Color(0xFF1F9D63);
    return TaqaOutlineTagButton(
      label: 'Inbox',
      width: TaqaUiScale.w(44),
      height: TaqaUiScale.h(20),
      onTap: _openConnectionRequests,
      borderColor: hasPending ? accent : null,
      textStyle: hasPending
          ? TaqaUiStyles.streakTag.copyWith(color: accent)
          : null,
      icon: Icon(
        Icons.notifications_rounded,
        size: TaqaUiScale.w(6),
        color: hasPending ? accent : TaqaUiColors.charcoal,
      ),
    );
  }

  Widget _buildMyClientsTab() {
    if (_loading) {
      return const Center(child: TaqaLoadingIndicator());
    }

    final displayClients = _clients.map((client) {
      var mapped = client;
      if (_dietBadgeSuppressedClientIds.contains(client.userId)) {
        mapped = mapped.copyWith(
          hasDietLogToReview: false,
          sharedDietLogCount: 0,
        );
      }
      if (_newClientBadgeSuppressedClientIds.contains(client.userId)) {
        mapped = mapped.copyWith(
          hasNewAssignment: false,
          newAssignmentCount: 0,
        );
      }
      return mapped;
    }).toList();

    final prioritizedClients = [...displayClients]
      ..sort((a, b) {
        final aHasPending =
            a.hasNewAssignment ||
            _supportChatUnreadClientIds.contains(a.userId) ||
            a.hasFormCheckToReview ||
            a.hasDietLogToReview ||
            a.hasUncheckedTrainingPlan;
        final bHasPending =
            b.hasNewAssignment ||
            _supportChatUnreadClientIds.contains(b.userId) ||
            b.hasFormCheckToReview ||
            b.hasDietLogToReview ||
            b.hasUncheckedTrainingPlan;
        if (aHasPending != bHasPending) {
          return bHasPending ? 1 : -1;
        }
        if (a.hasNewAssignment != b.hasNewAssignment) {
          return b.hasNewAssignment ? 1 : -1;
        }
        final aHasSupportUnread = _supportChatUnreadClientIds.contains(
          a.userId,
        );
        final bHasSupportUnread = _supportChatUnreadClientIds.contains(
          b.userId,
        );
        if (aHasSupportUnread != bHasSupportUnread) {
          return bHasSupportUnread ? 1 : -1;
        }
        if (a.newAssignmentCount != b.newAssignmentCount) {
          return b.newAssignmentCount.compareTo(a.newAssignmentCount);
        }
        if (a.hasFormCheckToReview != b.hasFormCheckToReview) {
          return b.hasFormCheckToReview ? 1 : -1;
        }
        if (a.sharedFormCheckCount != b.sharedFormCheckCount) {
          return b.sharedFormCheckCount.compareTo(a.sharedFormCheckCount);
        }
        if (a.hasDietLogToReview != b.hasDietLogToReview) {
          return b.hasDietLogToReview ? 1 : -1;
        }
        if (a.sharedDietLogCount != b.sharedDietLogCount) {
          return b.sharedDietLogCount.compareTo(a.sharedDietLogCount);
        }
        if (a.hasUncheckedTrainingPlan != b.hasUncheckedTrainingPlan) {
          return b.hasUncheckedTrainingPlan ? 1 : -1;
        }
        if (a.trainingPlanUncheckedCount != b.trainingPlanUncheckedCount) {
          return b.trainingPlanUncheckedCount.compareTo(
            a.trainingPlanUncheckedCount,
          );
        }
        return a.userId.compareTo(b.userId);
      });

    return TaqaRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: TaqaUiScale.insetsLTRB(20, 20, 20, 20),
        children: [
          const TaqaManagementSectionTitle(title: 'My Clients'),
          SizedBox(height: TaqaUiScale.h(10)),
          if (_clients.isEmpty)
            const TaqaEmptyStateRow(text: 'No assigned clients yet.')
          else
            ...prioritizedClients.map((client) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaqaExpertClientCard(
                  name: _clientDisplayName(client),
                  avatarUrl: _normalizeAvatarUrlForUi(client.avatarUrl),
                  status: client.activityStatus,
                  alerts: _clientAlerts(
                    client,
                    hasSupportChatUnread: _supportChatUnreadClientIds.contains(
                      client.userId,
                    ),
                  ),
                  onTap: () => _openClientDetail(client),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProgramsTab() {
    final clientCount = _clients.length;
    final templateCount = _planTemplates.length;
    final assignedTemplateCount = _planTemplates.where((template) {
      final count =
          int.tryParse('${template['assigned_client_count'] ?? 0}') ?? 0;
      return count > 0;
    }).length;
    final sortedTemplates = [..._planTemplates]
      ..sort((a, b) {
        final aTs = (a['created_at'] ?? '').toString();
        final bTs = (b['created_at'] ?? '').toString();
        return bTs.compareTo(aTs);
      });

    return Stack(
      children: [
        ListView(
          padding: TaqaUiScale.insetsLTRB(16, 20, 16, 96),
          children: [
            const TaqaManagementSectionTitle(
              title: 'Programs',
              subtitle:
                  'Create training templates and assign them to your clients.',
            ),
            SizedBox(height: TaqaUiScale.h(14)),
            Wrap(
              spacing: TaqaUiScale.w(10),
              runSpacing: TaqaUiScale.h(8),
              children: [
                TaqaOutlineTagButton(
                  label: '$clientCount clients',
                  width: TaqaUiScale.w(59),
                  height: TaqaUiScale.h(20),
                ),
                TaqaOutlineTagButton(
                  label: '$templateCount templates',
                  width: TaqaUiScale.w(69),
                  height: TaqaUiScale.h(20),
                ),
                TaqaOutlineTagButton(
                  label: '$assignedTemplateCount assigned',
                  width: TaqaUiScale.w(64),
                  height: TaqaUiScale.h(20),
                ),
              ],
            ),
            SizedBox(height: TaqaUiScale.h(22)),
            Text(
              'Template Library',
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(15),
                fontWeight: FontWeight.w700,
                height: 25 / 15,
                letterSpacing: 0,
                color: TaqaUiColors.unnamedColor1c1d17,
              ),
            ),
            SizedBox(height: TaqaUiScale.h(10)),
            if (sortedTemplates.isEmpty)
              const TaqaEmptyStateRow(text: 'No templates saved yet.')
            else
              ...sortedTemplates.map((template) {
                final templateId =
                    int.tryParse('${template['template_id'] ?? ''}') ?? 0;
                final title = (template['title'] ?? '').toString().trim();
                final dayCount =
                    int.tryParse('${template['day_count'] ?? 0}') ?? 0;
                final exerciseCount =
                    int.tryParse('${template['exercise_count'] ?? 0}') ?? 0;
                final assignedClientsRaw = template['assigned_clients'];
                final assignedClients = assignedClientsRaw is List
                    ? assignedClientsRaw
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList(growable: false)
                    : const <Map<String, dynamic>>[];
                final assignedClientsResolved = _enrichAssignedClientsAvatar(
                  assignedClients,
                );
                final assignedClientRaw = template['assigned_client'];
                final assignedClient = assignedClientRaw is Map
                    ? _enrichAssignedClientAvatar(
                        Map<String, dynamic>.from(assignedClientRaw),
                      )
                    : null;
                final assignedClientCount =
                    int.tryParse('${template['assigned_client_count'] ?? 0}') ??
                    0;
                final previewClients = assignedClientsResolved.isNotEmpty
                    ? assignedClientsResolved.take(3).toList(growable: false)
                    : (assignedClient != null
                          ? <Map<String, dynamic>>[assignedClient]
                          : const <Map<String, dynamic>>[]);
                final assigning = _assigningPlanTemplateIds.contains(
                  templateId,
                );
                final deleting = _deletingPlanTemplateIds.contains(templateId);
                return Padding(
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                  child: TaqaManagementListCard(
                    onTap: templateId <= 0
                        ? null
                        : () => _openTemplatePreviewSheet(template),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty ? 'Untitled template' : title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      color: TaqaUiColors.unnamedColor1c1d17,
                                      fontWeight: FontWeight.w700,
                                      fontSize: TaqaUiScale.sp(15),
                                      height: 18 / 15,
                                    ),
                                  ),
                                  SizedBox(height: TaqaUiScale.h(8)),
                                  Wrap(
                                    spacing: TaqaUiScale.w(8),
                                    runSpacing: TaqaUiScale.h(8),
                                    children: [
                                      TaqaManagementTag(
                                        label: '$dayCount days',
                                      ),
                                      TaqaManagementTag(
                                        label: '$exerciseCount exercises',
                                      ),
                                      if (assignedClientCount == 0)
                                        const TaqaManagementTag(
                                          label: 'Not assigned',
                                        )
                                      else
                                        TaqaManagementTag(
                                          label:
                                              '$assignedClientCount assigned',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: TaqaUiScale.w(10)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TaqaCompactActionButton(
                                  label: assigning ? 'Assigning...' : 'Assign',
                                  icon: Icons.group_add_outlined,
                                  loading: assigning,
                                  height: 38,
                                  onTap:
                                      (templateId <= 0 || assigning || deleting)
                                      ? null
                                      : () =>
                                            _openAssignTemplateSheet(template),
                                ),
                                SizedBox(width: TaqaUiScale.w(6)),
                                TaqaIconActionButton(
                                  tooltip: 'Delete template',
                                  icon: Icons.delete_outline,
                                  color: Colors.redAccent,
                                  loading: deleting,
                                  onTap:
                                      (templateId <= 0 || assigning || deleting)
                                      ? null
                                      : () => _deletePlanTemplate(template),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (assignedClientCount > 0 &&
                            previewClients.isNotEmpty) ...[
                          SizedBox(height: TaqaUiScale.h(10)),
                          InkWell(
                            borderRadius: TaqaUiScale.radius(5),
                            onTap: () => _openAssignedClientsSheet(
                              title.isEmpty ? 'Untitled template' : title,
                              assignedClientsResolved.isNotEmpty
                                  ? assignedClientsResolved
                                  : previewClients,
                            ),
                            child: Padding(
                              padding: TaqaUiScale.insetsLTRB(4, 4, 4, 4),
                              child: Row(
                                children: [
                                  TaqaAssignedClientsStack(
                                    clients: previewClients,
                                    totalCount: assignedClientCount,
                                  ),
                                  SizedBox(width: TaqaUiScale.w(10)),
                                  Expanded(
                                    child: Text(
                                      assignedClientCount == 1
                                          ? '1 assigned client'
                                          : '$assignedClientCount assigned clients',
                                      style: TextStyle(
                                        fontFamily:
                                            TaqaUiFontFamilies.interTight,
                                        color: TaqaUiColors.charcoal.withValues(
                                          alpha: 0.70,
                                        ),
                                        fontSize: TaqaUiScale.sp(12),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: TaqaUiColors.charcoal.withValues(
                                      alpha: 0.54,
                                    ),
                                    size: TaqaUiScale.w(18),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
        PositionedDirectional(
          end: TaqaUiScale.w(16),
          bottom: TaqaUiScale.h(16),
          child: TaqaFloatingAddButton(
            loading: _openingPlanCreator,
            onTap: _openingPlanCreator ? null : _openPlanCreatorSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionTab() {
    final items = [..._nutritionDocuments]
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        final aTs =
            a.createdAt ??
            a.updatedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTs =
            b.createdAt ??
            b.updatedAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });
    final pinnedCount = items.where((item) => item.isPinned).length;

    if (_loading) {
      return const Center(child: TaqaLoadingIndicator());
    }

    return TaqaRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: TaqaUiScale.insetsLTRB(16, 20, 16, 20),
        children: [
          const TaqaManagementSectionTitle(
            title: 'Nutrition',
            subtitle:
                'All assigned plan documents you uploaded for your current clients.',
          ),
          SizedBox(height: TaqaUiScale.h(14)),
          Row(
            children: [
              Expanded(
                child: TaqaManagementMetricCard(
                  label: 'Documents',
                  value: '${items.length}',
                ),
              ),
              SizedBox(width: TaqaUiScale.w(15)),
              Expanded(
                child: TaqaManagementMetricCard(
                  label: 'Pinned',
                  value: '$pinnedCount',
                ),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(22)),
          if (items.isEmpty)
            const TaqaEmptyStateRow(text: 'No uploaded plan documents yet.')
          else
            ...items.map((document) {
              final title = (document.documentTitle ?? '').trim().isNotEmpty
                  ? document.documentTitle!.trim()
                  : ((document.originalFilename ?? '').trim().isNotEmpty
                        ? document.originalFilename!.trim()
                        : 'Plan document');
              final clientLabel = (document.clientName ?? '').trim().isNotEmpty
                  ? document.clientName!.trim()
                  : 'Client';
              final isPinLoading = _pinningNutritionDocumentIds.contains(
                document.documentId,
              );
              final isDeleteLoading = _deletingNutritionDocumentIds.contains(
                document.documentId,
              );
              final isOpenLoading = _openingNutritionDocumentIds.contains(
                document.documentId,
              );
              return Padding(
                padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                child: TaqaManagementListCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                color: TaqaUiColors.unnamedColor1c1d17,
                                fontWeight: FontWeight.w700,
                                fontSize: TaqaUiScale.sp(15),
                                height: 18 / 15,
                              ),
                            ),
                          ),
                          if (document.isPinned)
                            Icon(
                              Icons.push_pin,
                              size: TaqaUiScale.w(16),
                              color: const Color(0xFFE07A00),
                            ),
                        ],
                      ),
                      SizedBox(height: TaqaUiScale.h(6)),
                      Text(
                        clientLabel,
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.charcoal.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w600,
                          fontSize: TaqaUiScale.sp(12),
                        ),
                      ),
                      SizedBox(height: TaqaUiScale.h(4)),
                      Text(
                        '${_formatBytes(document.fileSizeBytes)} • ${_formatDateTime(document.createdAt ?? document.updatedAt)}',
                        style: TextStyle(
                          fontFamily: TaqaUiFontFamilies.interTight,
                          color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
                          fontSize: TaqaUiScale.sp(12),
                        ),
                      ),
                      if ((document.originalFilename ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        SizedBox(height: TaqaUiScale.h(4)),
                        Text(
                          document.originalFilename!.trim(),
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            color: TaqaUiColors.charcoal.withValues(
                              alpha: 0.60,
                            ),
                            fontSize: TaqaUiScale.sp(12),
                          ),
                        ),
                      ],
                      SizedBox(height: TaqaUiScale.h(8)),
                      Row(
                        children: [
                          TaqaCompactActionButton(
                            label: 'Open',
                            icon: Icons.open_in_new,
                            loading: isOpenLoading,
                            onTap: isOpenLoading
                                ? null
                                : () => _openNutritionDocument(document),
                          ),
                          SizedBox(width: TaqaUiScale.w(8)),
                          TaqaCompactActionButton(
                            label: document.isPinned ? 'Unpin' : 'Pin',
                            icon: document.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            color: document.isPinned
                                ? const Color(0xFFE07A00)
                                : TaqaUiColors.charcoal,
                            loading: isPinLoading,
                            onTap: (isPinLoading || isDeleteLoading)
                                ? null
                                : () => _toggleNutritionDocumentPin(document),
                          ),
                          SizedBox(width: TaqaUiScale.w(8)),
                          TaqaIconActionButton(
                            tooltip: 'Delete document',
                            icon: Icons.delete_outline,
                            color: Colors.redAccent,
                            loading: isDeleteLoading,
                            onTap: (isDeleteLoading || isPinLoading)
                                ? null
                                : () => _deleteNutritionDocument(document),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 12, 20, 0),
            child: TaqaDashboardPageHeader(
              title: 'Coach Dashboard',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: _buildInboxButton(),
            ),
          ),
          Padding(
            padding: TaqaUiScale.insetsLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaPillTab(
                    label: 'My Clients',
                    active: _tabIndex == _tabMyClients,
                    onTap: () => _selectTab(_tabMyClients),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(16)),
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaPillTab(
                    label: 'Programs',
                    active: _tabIndex == _tabPrograms,
                    onTap: () => _selectTab(_tabPrograms),
                  ),
                ),
                SizedBox(width: TaqaUiScale.w(14)),
                SizedBox(
                  width: TaqaUiScale.w(109),
                  child: TaqaPillTab(
                    label: 'Nutrition',
                    active: _tabIndex == _tabNutrition,
                    onTap: () => _selectTab(_tabNutrition),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildMyClientsTab(),
                _buildProgramsTab(),
                _buildNutritionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
