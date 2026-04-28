import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/app_localizations.dart';
import '../services/coach/coach_habit_reminder_settings_service.dart';
import '../services/coach/diet_document_file_service.dart';
import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import 'expert_client_detail_page.dart';
import 'expert_connection_requests_page.dart';
import 'expert_progression_review_page.dart';

class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  static const int _tabMyClients = 0;
  static const int _tabAnalytics = 1;
  static const int _tabPrograms = 2;
  static const int _tabNutrition = 3;
  static const int _tabSettings = 4;
  static const int _tabProgression = 5;

  int _tabIndex = _tabMyClients;
  bool _loading = true;
  bool _generating = false;
  List<ProgressionClient> _clients = const [];
  List<ProgressionReview> _reviews = const [];
  List<CoachDietDocument> _nutritionDocuments = const [];
  final Set<int> _pinningNutritionDocumentIds = <int>{};
  final Set<int> _deletingNutritionDocumentIds = <int>{};
  final Set<int> _openingNutritionDocumentIds = <int>{};
  int _newPendingConnectionRequestCount = 0;
  final Set<int> _dietBadgeSuppressedClientIds = <int>{};
  final Set<int> _newClientBadgeSuppressedClientIds = <int>{};
  bool _loadingHabitReminderSettings = false;
  bool _savingHabitReminderSettings = false;
  bool _triggeringHabitReminderNow = false;
  bool _habitReminderSettingsLoaded = false;
  bool _autoHabitReminderEnabled = false;
  String _habitReminderScheduleType = 'weekly';
  int _habitReminderWeeklyDay = 0;
  int _habitReminderHourOfDay = 9;
  String _habitReminderTimeZone = 'UTC';

  @override
  void initState() {
    super.initState();
    _load();
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
        ProgressionReviewService.fetchAssignedDietDocuments(),
      ]);
      final fetchedClients = results[0] as List<ProgressionClient>;
      final fetchedReviews = results[1] as List<ProgressionReview>;
      final requestSummary = results[2] as CoachConnectionRequestSummary;
      final fetchedNutritionDocuments = results[3] as List<CoachDietDocument>;
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
      });
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
          message = 'Progression review generated.';
          break;
        case 'exists':
          message = 'A review already exists for this week.';
          break;
        case 'noop':
          message = (result['reason'] ?? 'No review generated.').toString();
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
    await Navigator.of(context).push(
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
      final localPath =
          await DietDocumentFileService.prepareLocalDietDocumentFile(
            url,
            suggestedFileName:
                document.originalFilename ?? document.documentTitle,
          );
      final opened = await launchUrl(
        Uri.file(localPath),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('Could not open downloaded document.');
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
    if (index == _tabSettings) {
      unawaited(_loadHabitReminderSettings(force: false));
    }
  }

  Future<void> _loadHabitReminderSettings({required bool force}) async {
    if (_loadingHabitReminderSettings) return;
    if (!force && _habitReminderSettingsLoaded) return;
    setState(() => _loadingHabitReminderSettings = true);
    try {
      final settings = await CoachHabitReminderSettingsService.fetchSettings();
      if (!mounted) return;
      setState(() {
        _autoHabitReminderEnabled = settings.autoEnabled;
        final schedule = (settings.scheduleType ?? '').trim().toLowerCase();
        _habitReminderScheduleType = schedule == 'daily' ? 'daily' : 'weekly';
        _habitReminderWeeklyDay = settings.weeklyDay.clamp(0, 6);
        _habitReminderHourOfDay = settings.hourOfDay.clamp(0, 23);
        _habitReminderTimeZone = settings.timeZone.trim().isEmpty
            ? 'UTC'
            : settings.timeZone.trim();
        _habitReminderSettingsLoaded = true;
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
        setState(() => _loadingHabitReminderSettings = false);
      }
    }
  }

  Future<void> _saveHabitReminderSettings() async {
    if (_savingHabitReminderSettings) return;
    setState(() => _savingHabitReminderSettings = true);
    try {
      final updated = await CoachHabitReminderSettingsService.updateSettings(
        autoEnabled: _autoHabitReminderEnabled,
        scheduleType: _habitReminderScheduleType,
        weeklyDay: _habitReminderWeeklyDay,
        hourOfDay: _habitReminderHourOfDay,
      );
      if (!mounted) return;
      setState(() {
        _autoHabitReminderEnabled = updated.autoEnabled;
        final schedule = (updated.scheduleType ?? '').trim().toLowerCase();
        _habitReminderScheduleType = schedule == 'daily' ? 'daily' : 'weekly';
        _habitReminderWeeklyDay = updated.weeklyDay.clamp(0, 6);
        _habitReminderHourOfDay = updated.hourOfDay.clamp(0, 23);
        _habitReminderTimeZone = updated.timeZone.trim().isEmpty
            ? 'UTC'
            : updated.timeZone.trim();
        _habitReminderSettingsLoaded = true;
      });
      AppToast.show(
        context,
        'Habit reminder settings saved.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _savingHabitReminderSettings = false);
      }
    }
  }

  Future<void> _triggerHabitRemindersNow() async {
    if (_triggeringHabitReminderNow) return;
    setState(() => _triggeringHabitReminderNow = true);
    try {
      final result = await CoachHabitReminderSettingsService.triggerNow();
      if (!mounted) return;
      final triggered = (result['triggered_clients'] as num?)?.toInt() ?? 0;
      final targeted = (result['targeted_clients'] as num?)?.toInt() ?? 0;
      AppToast.show(
        context,
        triggered > 0
            ? 'Triggered reminders for $triggered of $targeted clients.'
            : 'No reminder was triggered right now.',
        type: triggered > 0 ? AppToastType.success : AppToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _triggeringHabitReminderNow = false);
      }
    }
  }

  String _appBarTitle(AppLocalizations t) {
    switch (_tabIndex) {
      case _tabMyClients:
        return 'My Clients';
      case _tabAnalytics:
        return 'Analytics';
      case _tabPrograms:
        return 'Programs';
      case _tabNutrition:
        return 'Nutrition';
      case _tabSettings:
        return t.translate('settings');
      case _tabProgression:
        return 'Progression Clients';
      default:
        return t.translate('expert_dashboard_title');
    }
  }

  Widget _buildMyClientsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
            a.hasFormCheckToReview ||
            a.hasDietLogToReview;
        final bHasPending =
            b.hasNewAssignment ||
            b.hasFormCheckToReview ||
            b.hasDietLogToReview;
        if (aHasPending != bHasPending) {
          return bHasPending ? 1 : -1;
        }
        if (a.hasNewAssignment != b.hasNewAssignment) {
          return b.hasNewAssignment ? 1 : -1;
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
        return a.userId.compareTo(b.userId);
      });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle(title: 'My Clients'),
          const SizedBox(height: 10),
          if (_clients.isEmpty)
            const _EmptyCard(text: 'No assigned clients yet.')
          else
            ...prioritizedClients.map((client) {
              final totalReviews = _reviews
                  .where((r) => r.userId == client.userId)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClientOverviewCard(
                  client: client,
                  reviewCount: totalReviews,
                  onView: () => _openClientDetail(client),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab(AppLocalizations t) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(
          title: t.translate('expert_dash_sec_analytics'),
          subtitle: t.translate('expert_dash_sec_analytics_body'),
        ),
        const SizedBox(height: 12),
        const _EmptyCard(text: 'Analytics workspace coming soon.'),
      ],
    );
  }

  Widget _buildProgramsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _SectionTitle(
          title: 'Programs',
          subtitle: 'Manage training programs, templates, and updates.',
        ),
        SizedBox(height: 12),
        _EmptyCard(text: 'Programs workspace coming soon.'),
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
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle(
            title: 'Nutrition',
            subtitle:
                'All assigned plan documents you uploaded for your current clients.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Documents',
                  value: '${items.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(label: 'Pinned', value: '$pinnedCount'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const _EmptyCard(text: 'No uploaded plan documents yet.')
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (document.isPinned)
                            const Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Colors.orangeAccent,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        clientLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatBytes(document.fileSizeBytes)} • ${_formatDateTime(document.createdAt ?? document.updatedAt)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if ((document.originalFilename ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          document.originalFilename!.trim(),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: isOpenLoading
                                ? null
                                : () => _openNutritionDocument(document),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: isOpenLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new, size: 13),
                            label: const Text('Open'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (isPinLoading || isDeleteLoading)
                                ? null
                                : () => _toggleNutritionDocumentPin(document),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: document.isPinned
                                  ? Colors.orangeAccent
                                  : Colors.white70,
                              side: BorderSide(
                                color: document.isPinned
                                    ? Colors.orangeAccent
                                    : Colors.white24,
                              ),
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: isPinLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : Icon(
                                    document.isPinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                    size: 13,
                                  ),
                            label: Text(document.isPinned ? 'Unpin' : 'Pin'),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: (isDeleteLoading || isPinLoading)
                                ? null
                                : () => _deleteNutritionDocument(document),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: isDeleteLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline, size: 13),
                            label: const Text('Delete'),
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

  Widget _buildSettingsTab(AppLocalizations t) {
    const weekdayOptions = <MapEntry<int, String>>[
      MapEntry<int, String>(0, 'Monday'),
      MapEntry<int, String>(1, 'Tuesday'),
      MapEntry<int, String>(2, 'Wednesday'),
      MapEntry<int, String>(3, 'Thursday'),
      MapEntry<int, String>(4, 'Friday'),
      MapEntry<int, String>(5, 'Saturday'),
      MapEntry<int, String>(6, 'Sunday'),
    ];
    final hourOptions = List<int>.generate(24, (index) => index);
    final controlsDisabled =
        _loadingHabitReminderSettings || _savingHabitReminderSettings;
    final serverTimeLabel = _habitReminderTimeZone.trim().isEmpty
        ? 'UTC'
        : _habitReminderTimeZone.trim();
    final scheduleSubtitle = _habitReminderScheduleType == 'weekly'
        ? 'Choose one weekday and one hour.'
        : 'Choose one hour for daily trigger.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(
          title: t.translate('settings'),
          subtitle: 'Coach-side preferences and tools. Uses server time.',
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Habit Reminder Automation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Automatic reminder scheduling for all assigned clients. Server time: $serverTimeLabel',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _autoHabitReminderEnabled,
                onChanged: controlsDisabled
                    ? null
                    : (value) => setState(() => _autoHabitReminderEnabled = value),
                title: const Text(
                  'Auto send habit reminders to all clients',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Enable weekly or daily automation.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    selected: _habitReminderScheduleType == 'weekly',
                    label: const Text('Weekly'),
                    onSelected:
                        !_autoHabitReminderEnabled || controlsDisabled
                        ? null
                        : (_) => setState(
                            () => _habitReminderScheduleType = 'weekly',
                          ),
                    selectedColor: AppColors.accent.withValues(alpha: 0.24),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    labelStyle: TextStyle(
                      color: _habitReminderScheduleType == 'weekly'
                          ? Colors.white
                          : Colors.white70,
                    ),
                    side: BorderSide(
                      color: _habitReminderScheduleType == 'weekly'
                          ? AppColors.accent.withValues(alpha: 0.7)
                          : Colors.white24,
                    ),
                  ),
                  ChoiceChip(
                    selected: _habitReminderScheduleType == 'daily',
                    label: const Text('Daily'),
                    onSelected:
                        !_autoHabitReminderEnabled || controlsDisabled
                        ? null
                        : (_) => setState(
                            () => _habitReminderScheduleType = 'daily',
                          ),
                    selectedColor: AppColors.accent.withValues(alpha: 0.24),
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    labelStyle: TextStyle(
                      color: _habitReminderScheduleType == 'daily'
                          ? Colors.white
                          : Colors.white70,
                    ),
                    side: BorderSide(
                      color: _habitReminderScheduleType == 'daily'
                          ? AppColors.accent.withValues(alpha: 0.7)
                          : Colors.white24,
                    ),
                  ),
                ],
              ),
              if (_autoHabitReminderEnabled) ...[
                const SizedBox(height: 4),
                Text(
                  scheduleSubtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (_habitReminderScheduleType == 'weekly') ...[
                  DropdownButtonFormField<int>(
                    initialValue: _habitReminderWeeklyDay,
                    decoration: const InputDecoration(
                      labelText: 'Day of week',
                    ),
                    dropdownColor: AppColors.cardDark,
                    items: weekdayOptions
                        .map(
                          (entry) => DropdownMenuItem<int>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: controlsDisabled
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _habitReminderWeeklyDay = value);
                          },
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _habitReminderHourOfDay,
                  decoration: const InputDecoration(
                    labelText: 'Hour (0-23)',
                  ),
                  dropdownColor: AppColors.cardDark,
                  items: hourOptions
                      .map(
                        (hour) => DropdownMenuItem<int>(
                          value: hour,
                          child: Text(hour.toString().padLeft(2, '0')),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: controlsDisabled
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _habitReminderHourOfDay = value);
                        },
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: controlsDisabled
                          ? null
                          : _saveHabitReminderSettings,
                      child: Text(
                        _savingHabitReminderSettings
                            ? 'Saving...'
                            : 'Save Auto Reminder Settings',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _triggeringHabitReminderNow
                          ? null
                          : _triggerHabitRemindersNow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      icon: _triggeringHabitReminderNow
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(Icons.flash_on_outlined, size: 16),
                      label: Text(
                        _triggeringHabitReminderNow
                            ? 'Triggering...'
                            : 'Send Habit Reminders Now',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingHabitReminderSettings)
          const _EmptyCard(text: 'Loading reminder settings...'),
      ],
    );
  }

  Widget _buildProgressionTab() {
    final pendingCount = _reviews
        .where((r) => r.status == 'pending_expert' || r.status == 'reviewed')
        .length;
    final appliedCount = _reviews.where((r) => r.status == 'applied').length;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _TopMetricRow(
            pendingCount: pendingCount,
            appliedCount: appliedCount,
            clientCount: _clients.length,
          ),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'Progression Clients',
            subtitle:
                'Generate weekly progression reviews for clients assigned to you.',
          ),
          const SizedBox(height: 10),
          if (_clients.isEmpty)
            const _EmptyCard(text: 'No assigned clients yet.')
          else
            ..._clients.map(
              (client) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClientCard(
                  client: client,
                  generating: _generating,
                  onGenerate: () =>
                      _generateReview(client.userId, force: false),
                  onForceGenerate: () =>
                      _generateReview(client.userId, force: true),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const _SectionTitle(
            title: 'Progression Reviews',
            subtitle:
                'Open a review to approve, edit, reject, and apply final changes.',
          ),
          const SizedBox(height: 10),
          if (_reviews.isEmpty)
            const _EmptyCard(text: 'No progression reviews yet.')
          else
            ..._reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewListCard(
                  review: review,
                  onTap: () => _openReview(review),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    const tabs = <_CoachBottomTab>[
      _CoachBottomTab(label: 'My Clients', icon: Icons.people_alt_outlined),
      _CoachBottomTab(label: 'Analytics', icon: Icons.analytics_outlined),
      _CoachBottomTab(label: 'Programs', icon: Icons.fitness_center_outlined),
      _CoachBottomTab(label: 'Nutrition', icon: Icons.restaurant_menu_outlined),
      _CoachBottomTab(label: 'Settings', icon: Icons.settings_outlined),
      _CoachBottomTab(label: 'Progression', icon: Icons.trending_up_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: tabs.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final tab = tabs[i];
              final selected = i == _tabIndex;
              return _BottomTabButton(
                label: tab.label,
                icon: tab.icon,
                selected: selected,
                onTap: () => _selectTab(i),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final showRequestsButton = _tabIndex == _tabMyClients;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(_appBarTitle(t)),
        actions: [
          if (showRequestsButton)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Material(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _openConnectionRequests,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.how_to_reg_rounded,
                            size: 14,
                            color: _newPendingConnectionRequestCount > 0
                                ? const Color(0xFF4ADE80)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Inbox',
                            style: TextStyle(
                              color: _newPendingConnectionRequestCount > 0
                                  ? const Color(0xFFA7F3D0)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (_newPendingConnectionRequestCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1F9D63,
                                ).withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _newPendingConnectionRequestCount > 99
                                    ? '99+'
                                    : '$_newPendingConnectionRequestCount',
                                style: const TextStyle(
                                  color: Color(0xFFA7F3D0),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildMyClientsTab(),
          _buildAnalyticsTab(t),
          _buildProgramsTab(),
          _buildNutritionTab(),
          _buildSettingsTab(t),
          _buildProgressionTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class _CoachBottomTab {
  const _CoachBottomTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.18)
          : AppColors.cardDark,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 102),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.accent : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.accent : Colors.white70,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMetricRow extends StatelessWidget {
  const _TopMetricRow({
    required this.pendingCount,
    required this.appliedCount,
    required this.clientCount,
  });

  final int pendingCount;
  final int appliedCount;
  final int clientCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: 'Clients', value: '$clientCount'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: 'Pending', value: '$pendingCount'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: 'Applied', value: '$appliedCount'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        if ((subtitle ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: Colors.white60)),
        ],
      ],
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.generating,
    required this.onGenerate,
    required this.onForceGenerate,
  });

  final ProgressionClient client;
  final bool generating;
  final VoidCallback onGenerate;
  final VoidCallback onForceGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            client.name ?? 'Client #${client.userId}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            client.email ?? 'user_id: ${client.userId}',
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: generating ? null : onGenerate,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Generate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: generating ? null : onForceGenerate,
                  child: Text(generating ? 'Working...' : 'Force'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientOverviewCard extends StatelessWidget {
  const _ClientOverviewCard({
    required this.client,
    required this.reviewCount,
    required this.onView,
  });

  final ProgressionClient client;
  final int reviewCount;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final clientName = client.name ?? 'Client #${client.userId}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          _ClientAvatar(name: clientName, avatarUrl: client.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (client.hasNewAssignment) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1F9D63,
                          ).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: 0.65),
                          ),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    _ActivityStatusDot(
                      status: client.activityStatus,
                      inactiveDays: client.inactiveDays,
                    ),
                  ],
                ),
                if (client.hasNewAssignment) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 14,
                        color: Color(0xFF4ADE80),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          client.newAssignmentCount > 1
                              ? 'New client assignments (${client.newAssignmentCount})'
                              : 'New client assignment',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (client.hasFormCheckToReview) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.notification_important_outlined,
                        size: 14,
                        color: Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          client.sharedFormCheckCount > 1
                              ? 'Awaiting your reply (${client.sharedFormCheckCount})'
                              : 'Awaiting your reply',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (client.hasDietLogToReview) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 14,
                        color: Color(0xFF5FD8FF),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          client.sharedDietLogCount > 1
                              ? 'New diet logs (${client.sharedDietLogCount})'
                              : 'New diet log',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5FD8FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatusDot extends StatelessWidget {
  const _ActivityStatusDot({required this.status, this.inactiveDays});

  final String? status;
  final int? inactiveDays;

  Color _color() {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'green':
        return Colors.greenAccent.shade400;
      case 'yellow':
        return Colors.amber.shade400;
      case 'red':
        return Colors.redAccent.shade200;
      default:
        return Colors.redAccent.shade200;
    }
  }

  String _label() {
    final normalized = (status ?? '').trim().toLowerCase();
    if (normalized == 'green') return 'Active';
    if (normalized == 'yellow') {
      if (inactiveDays != null) return 'Inactive ${inactiveDays!}d';
      return 'Inactive 3d+';
    }
    if (inactiveDays != null) return 'Inactive ${inactiveDays!}d';
    return 'Inactive 7d+';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Tooltip(
      message: _label(),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
          border: Border.all(color: Colors.black, width: 0.7),
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  String _initials() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (avatarUrl ?? '').trim();
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.white10,
      foregroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      onForegroundImageError: (_, _) {},
      child: Text(
        _initials(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({required this.review, required this.onTap});

  final ProgressionReview review;
  final VoidCallback onTap;

  Color _statusColor() {
    switch (review.status) {
      case 'applied':
        return AppColors.successGreen;
      case 'failed':
        return AppColors.errorRed;
      case 'pending_expert':
        return Colors.orangeAccent;
      case 'reviewed':
        return AppColors.accent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.clientName ?? 'Client #${review.userId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Week ${review.weekStart ?? '-'} • ${review.itemCount} items',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  if ((review.aiSummary ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      review.aiSummary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    review.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}
