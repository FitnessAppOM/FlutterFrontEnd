import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/base_url.dart';
import '../localization/app_localizations.dart';
import '../services/coach/coach_habit_reminder_settings_service.dart';
import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/diet_document_file_service.dart';
import '../services/core/pdf_open_service.dart';
import '../services/coach/progression_review_service.dart';
import '../services/core/navigation_service.dart';
import '../services/training/training_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/taqa_ui_colors.dart';
import '../widgets/training/exercise_picker_sheet.dart';
import 'expert_client_detail_page.dart';
import 'expert_connection_requests_page.dart';
import 'expert_progression_review_page.dart';

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
  static const int _tabSettings = 3;

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
  bool _loadingHabitReminderSettings = false;
  bool _savingHabitReminderSettings = false;
  bool _triggeringHabitReminderNow = false;
  bool _openingPlanCreator = false;
  bool _habitReminderSettingsLoaded = false;
  bool _loadingCoachPinInSettings = false;
  bool _coachPinLoadedInSettings = false;
  String? _coachPin;
  bool _autoHabitReminderEnabled = false;
  String _habitReminderScheduleType = 'weekly';
  int _habitReminderWeeklyDay = 0;
  int _habitReminderHourOfDay = 9;
  String _habitReminderTimeZone = 'UTC';

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

  Future<void> _openPlanCreatorSheet() async {
    if (_openingPlanCreator) return;
    setState(() => _openingPlanCreator = true);
    final libraryExercises = <ExercisePickerItem>[];
    try {
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
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
      setState(() => _openingPlanCreator = false);
      return;
    }
    if (libraryExercises.isEmpty) {
      if (mounted) {
        AppToast.show(
          context,
          'Exercise library is empty or unavailable.',
          type: AppToastType.error,
        );
        setState(() => _openingPlanCreator = false);
      }
      return;
    }
    if (!mounted) return;

    var title = '';
    var submitting = false;
    var submittingMessage = '';
    final planDays = <_PlanDraftDay>[
      _PlanDraftDay(
        dayLabel: 'Day 1',
        exercises: [
          _PlanDraftExercise(
            exerciseId: libraryExercises.first.id,
            sets: 3,
            reps: 10,
            rir: 2,
          ),
        ],
      ),
    ];

    String exerciseNameById(int exerciseId) {
      for (final exercise in libraryExercises) {
        if (exercise.id == exerciseId) return exercise.name;
      }
      return '';
    }

    Future<void> submitPlan(StateSetter setModalState) async {
      if (submitting) return;
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty) {
        AppToast.show(
          context,
          'Add a template title.',
          type: AppToastType.error,
        );
        return;
      }
      if (planDays.isEmpty) {
        AppToast.show(
          context,
          'Add at least one day.',
          type: AppToastType.error,
        );
        return;
      }

      final payloadDays = <Map<String, dynamic>>[];
      for (var dayIndex = 0; dayIndex < planDays.length; dayIndex++) {
        final day = planDays[dayIndex];
        final exercises = <Map<String, dynamic>>[];
        if (day.exercises.isEmpty) {
          AppToast.show(
            context,
            'Day ${dayIndex + 1} must include at least one exercise.',
            type: AppToastType.error,
          );
          return;
        }
        for (var exIndex = 0; exIndex < day.exercises.length; exIndex++) {
          final ex = day.exercises[exIndex];
          if (ex.exerciseId <= 0) {
            AppToast.show(
              context,
              'Day ${dayIndex + 1}, exercise ${exIndex + 1}: invalid exercise.',
              type: AppToastType.error,
            );
            return;
          }
          if (ex.sets < 1 || ex.reps < 1) {
            AppToast.show(
              context,
              'Day ${dayIndex + 1}, exercise ${exIndex + 1}: sets/reps must be >= 1.',
              type: AppToastType.error,
            );
            return;
          }
          exercises.add({
            'exercise_id': ex.exerciseId,
            'sets': ex.sets,
            'reps': ex.reps,
            'rir': ex.rir,
          });
        }
        payloadDays.add({
          'day_label': day.dayLabel.trim().isEmpty
              ? 'Day ${dayIndex + 1}'
              : day.dayLabel.trim(),
          'exercises': exercises,
        });
      }

      setModalState(() {
        submitting = true;
        submittingMessage = 'Saving template...';
      });
      try {
        final result = await ProgressionReviewService.createPlanTemplate(
          title: trimmedTitle,
          days: payloadDays,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        final templateId = (result['template_id'] ?? '').toString();
        AppToast.show(
          context,
          templateId.isNotEmpty
              ? 'Template saved (#$templateId).'
              : 'Template saved.',
          type: AppToastType.success,
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        setModalState(() {
          submitting = false;
          submittingMessage = '';
        });
        AppToast.show(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          type: AppToastType.error,
        );
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Plan Template',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        enabled: !submitting,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Template title',
                        ),
                        onChanged: (value) => title = value,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Exercise library loaded: ${libraryExercises.length}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(planDays.length, (dayIndex) {
                        final day = planDays[dayIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: day.dayLabel,
                                        enabled: !submitting,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: InputDecoration(
                                          labelText:
                                              'Day ${dayIndex + 1} label',
                                        ),
                                        onChanged: (value) {
                                          day.dayLabel = value;
                                        },
                                      ),
                                    ),
                                    if (planDays.length > 1) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: submitting
                                            ? null
                                            : () {
                                                setModalState(() {
                                                  planDays.removeAt(dayIndex);
                                                });
                                              },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...List.generate(day.exercises.length, (
                                  exIndex,
                                ) {
                                  final ex = day.exercises[exIndex];
                                  final selectedExerciseName = exerciseNameById(
                                    ex.exerciseId,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardDark,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            onTap: submitting
                                                ? null
                                                : () async {
                                                    final picked =
                                                        await showExercisePickerSheet(
                                                          context: context,
                                                          options:
                                                              libraryExercises,
                                                          selectedId:
                                                              ex.exerciseId > 0
                                                              ? ex.exerciseId
                                                              : null,
                                                        );
                                                    if (picked == null) return;
                                                    setModalState(
                                                      () => ex.exerciseId =
                                                          picked.id,
                                                    );
                                                  },
                                            child: InputDecorator(
                                              decoration: const InputDecoration(
                                                labelText: 'Exercise',
                                                suffixIcon: Icon(
                                                  Icons.search_rounded,
                                                ),
                                              ),
                                              child: Text(
                                                selectedExerciseName.isEmpty
                                                    ? 'Select exercise'
                                                    : selectedExerciseName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color:
                                                      selectedExerciseName
                                                          .isEmpty
                                                      ? Colors.white54
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: '${ex.sets}',
                                                  enabled: !submitting,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Sets',
                                                      ),
                                                  onChanged: (value) {
                                                    ex.sets =
                                                        int.tryParse(
                                                          value.trim(),
                                                        ) ??
                                                        0;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: '${ex.reps}',
                                                  enabled: !submitting,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'Reps',
                                                      ),
                                                  onChanged: (value) {
                                                    ex.reps =
                                                        int.tryParse(
                                                          value.trim(),
                                                        ) ??
                                                        0;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextFormField(
                                                  initialValue: ex.rir == null
                                                      ? ''
                                                      : '${ex.rir}',
                                                  enabled: !submitting,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                  decoration:
                                                      const InputDecoration(
                                                        labelText: 'RIR',
                                                      ),
                                                  onChanged: (value) {
                                                    final raw = value.trim();
                                                    ex.rir = raw.isEmpty
                                                        ? null
                                                        : int.tryParse(raw);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                onPressed:
                                                    (submitting ||
                                                        day.exercises.length ==
                                                            1)
                                                    ? null
                                                    : () {
                                                        setModalState(() {
                                                          day.exercises
                                                              .removeAt(
                                                                exIndex,
                                                              );
                                                        });
                                                      },
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: submitting
                                        ? null
                                        : () {
                                            setModalState(() {
                                              day.exercises.add(
                                                _PlanDraftExercise(
                                                  exerciseId:
                                                      libraryExercises.first.id,
                                                  sets: 3,
                                                  reps: 10,
                                                  rir: 2,
                                                ),
                                              );
                                            });
                                          },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Exercise'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: submitting
                                ? null
                                : () {
                                    if (planDays.length >= 7) return;
                                    setModalState(() {
                                      final nextIndex = planDays.length + 1;
                                      planDays.add(
                                        _PlanDraftDay(
                                          dayLabel: 'Day $nextIndex',
                                          exercises: [
                                            _PlanDraftExercise(
                                              exerciseId:
                                                  libraryExercises.first.id,
                                              sets: 3,
                                              reps: 10,
                                              rir: 2,
                                            ),
                                          ],
                                        ),
                                      );
                                    });
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Day'),
                          ),
                        ],
                      ),
                      if (submittingMessage.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          submittingMessage,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () => submitPlan(setModalState),
                          child: Text(
                            submitting ? 'Saving...' : 'Save Template',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() => _openingPlanCreator = false);
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
    if (templateId <= 0) return;
    final templateTitle = (template['title'] ?? '').toString().trim();
    final clients = [..._clients]
      ..sort(
        (a, b) => _clientDisplayName(
          a,
        ).toLowerCase().compareTo(_clientDisplayName(b).toLowerCase()),
      );
    var selectedClientId = clients.first.userId;
    var archiveExisting = true;
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign "${templateTitle.isEmpty ? 'Template' : templateTitle}"',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: selectedClientId,
                        decoration: const InputDecoration(labelText: 'Client'),
                        dropdownColor: AppColors.cardDark,
                        items: clients
                            .map(
                              (client) => DropdownMenuItem<int>(
                                value: client.userId,
                                child: Text(_clientDisplayName(client)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setModalState(() => selectedClientId = value);
                              },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: archiveExisting,
                        onChanged: submitting
                            ? null
                            : (value) {
                                setModalState(() => archiveExisting = value);
                              },
                        title: const Text(
                          'Archive existing active plan',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  setModalState(() => submitting = true);
                                  setState(
                                    () => _assigningPlanTemplateIds.add(
                                      templateId,
                                    ),
                                  );
                                  try {
                                    final result =
                                        await ProgressionReviewService.assignPlanTemplateToClient(
                                          templateId: templateId,
                                          clientUserId: selectedClientId,
                                          archiveExisting: archiveExisting,
                                        );
                                    if (!mounted || !context.mounted) return;
                                    Navigator.of(context).pop();
                                    final programId =
                                        (result['program_id'] ?? '').toString();
                                    AppToast.show(
                                      context,
                                      programId.isNotEmpty
                                          ? 'Assigned successfully (Program #$programId).'
                                          : 'Assigned successfully.',
                                      type: AppToastType.success,
                                    );
                                    await _load();
                                  } catch (e) {
                                    if (!mounted || !context.mounted) return;
                                    setModalState(() => submitting = false);
                                    AppToast.show(
                                      context,
                                      e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      ),
                                      type: AppToastType.error,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(
                                        () => _assigningPlanTemplateIds.remove(
                                          templateId,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: Text(submitting ? 'Assigning...' : 'Assign'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePlanTemplate(Map<String, dynamic> template) async {
    final templateId = int.tryParse('${template['template_id'] ?? ''}') ?? 0;
    if (templateId <= 0 || _deletingPlanTemplateIds.contains(templateId)) {
      return;
    }
    final title = (template['title'] ?? '').toString().trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          title.isEmpty
              ? 'Are you sure you want to delete this template?'
              : 'Are you sure you want to delete "$title"?',
        ),
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

  String _formatAssignedAt(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return _formatDateTime(parsed);
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

  Map<String, dynamic> _enrichAssignedClientAvatar(Map<String, dynamic> item) {
    final userId = int.tryParse('${item['user_id'] ?? ''}') ?? 0;
    final cachedAvatar = userId > 0 ? _avatarFromKnownClients(userId) : null;
    final rawAvatar = _normalizeAvatarUrlForUi(item['avatar_url']);
    final resolvedAvatar = (cachedAvatar ?? '').isNotEmpty
        ? cachedAvatar
        : rawAvatar;
    return {...item, 'avatar_url': resolvedAvatar};
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                Text(
                  (templateTitle).trim().isEmpty
                      ? 'Assigned clients'
                      : 'Assigned • $templateTitle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: resolvedAssignedClients.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Colors.white12),
                    itemBuilder: (context, index) {
                      final item = resolvedAssignedClients[index];
                      final name =
                          (item['name'] ?? '').toString().trim().isEmpty
                          ? 'Client #${item['user_id'] ?? ''}'
                          : (item['name'] ?? '').toString().trim();
                      final avatarUrl = (item['avatar_url'] ?? '')
                          .toString()
                          .trim();
                      final assignedAt = _formatAssignedAt(
                        (item['assigned_at'] ?? '').toString(),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            _StackClientAvatar(
                              name: name,
                              avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
                              radius: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Assigned $assignedAt',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTemplatePreviewSheet(Map<String, dynamic> template) async {
    final title = (template['title'] ?? '').toString().trim();
    final daysRaw = template['days'];
    final templateDays = daysRaw is List
        ? daysRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Template preview' : title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (templateDays.isEmpty)
                    const Text(
                      'No day details available for this template.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: templateDays.length,
                        itemBuilder: (context, index) {
                          final day = templateDays[index];
                          final dayIndex =
                              int.tryParse('${day['day_index'] ?? ''}') ?? 0;
                          final dayLabel = (day['day_label'] ?? '')
                              .toString()
                              .trim();
                          final exercisesRaw = day['exercises'];
                          final exercises = exercisesRaw is List
                              ? exercisesRaw
                                    .whereType<Map>()
                                    .map(
                                      (item) => Map<String, dynamic>.from(item),
                                    )
                                    .toList(growable: false)
                              : const <Map<String, dynamic>>[];
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.black,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dayLabel.isEmpty
                                      ? 'Day ${dayIndex > 0 ? dayIndex : '?'}'
                                      : dayLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (exercises.isEmpty)
                                  const Text(
                                    'No exercises',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  ...exercises.map((exercise) {
                                    final exerciseName =
                                        (exercise['exercise_name'] ?? '')
                                            .toString()
                                            .trim();
                                    final sets = int.tryParse(
                                      '${exercise['sets'] ?? ''}',
                                    );
                                    final reps = int.tryParse(
                                      '${exercise['reps'] ?? ''}',
                                    );
                                    final rir = int.tryParse(
                                      '${exercise['rir'] ?? ''}',
                                    );
                                    final volumeText =
                                        '${(sets ?? 0) > 0 ? sets : '-'} x ${(reps ?? 0) > 0 ? reps : '-'}';
                                    final rirText = rir == null
                                        ? ''
                                        : ' • RIR $rir';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '${exerciseName.isEmpty ? 'Exercise' : exerciseName}  $volumeText$rirText',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
    if (index == _tabSettings) {
      unawaited(_loadHabitReminderSettings(force: false));
      unawaited(_loadCoachPinForSettings(force: false));
    }
  }

  Future<void> _loadCoachPinForSettings({required bool force}) async {
    if (_loadingCoachPinInSettings) return;
    if (!force && _coachPinLoadedInSettings) return;
    setState(() => _loadingCoachPinInSettings = true);
    try {
      final coachPin = await ProgressionReviewService.fetchMyCoachCode();
      if (!mounted) return;
      setState(() {
        _coachPin = coachPin;
        _coachPinLoadedInSettings = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coachPin = null;
        _coachPinLoadedInSettings = true;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCoachPinInSettings = false);
      }
    }
  }

  Future<void> _copyCoachPinFromSettings() async {
    final pin = (_coachPin ?? '').trim();
    if (pin.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pin));
    if (!mounted) return;
    AppToast.show(context, 'Coach PIN copied', type: AppToastType.success);
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
      case _tabPrograms:
        return 'Programs';
      case _tabNutrition:
        return 'Nutrition';
      case _tabSettings:
        return t.translate('settings');
      default:
        return t.translate('expert_dashboard_title');
    }
  }

  Widget _buildMyClientsTab() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: TaqaUiColors.lime),
      );
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
                  hasSupportChatUnread: _supportChatUnreadClientIds.contains(
                    client.userId,
                  ),
                  reviewCount: totalReviews,
                  onView: () => _openClientDetail(client),
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
    final unassignedTemplateCount = templateCount - assignedTemplateCount;
    final sortedTemplates = [..._planTemplates]
      ..sort((a, b) {
        final aTs = (a['created_at'] ?? '').toString();
        final bTs = (b['created_at'] ?? '').toString();
        return bTs.compareTo(aTs);
      });

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardDark,
                AppColors.cardDark.withValues(alpha: 0.72),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 470;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Programs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create polished training templates and assign them in one tap.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  if (compact)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openingPlanCreator
                            ? null
                            : _openPlanCreatorSheet,
                        icon: _openingPlanCreator
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TaqaUiColors.lime,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(
                          _openingPlanCreator
                              ? 'Opening...'
                              : 'Create New Template',
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ProgramStatPill(
                                icon: Icons.people_alt_outlined,
                                label: '$clientCount clients',
                              ),
                              _ProgramStatPill(
                                icon: Icons.dashboard_outlined,
                                label: '$templateCount templates',
                              ),
                              _ProgramStatPill(
                                icon: Icons.link_outlined,
                                label: '$assignedTemplateCount assigned',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _openingPlanCreator
                              ? null
                              : _openPlanCreatorSheet,
                          icon: _openingPlanCreator
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TaqaUiColors.lime,
                                  ),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            _openingPlanCreator
                                ? 'Opening...'
                                : 'Create Template',
                          ),
                        ),
                      ],
                    ),
                  if (compact) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProgramStatPill(
                          icon: Icons.people_alt_outlined,
                          label: '$clientCount clients',
                        ),
                        _ProgramStatPill(
                          icon: Icons.dashboard_outlined,
                          label: '$templateCount templates',
                        ),
                        _ProgramStatPill(
                          icon: Icons.link_outlined,
                          label: '$assignedTemplateCount assigned',
                        ),
                      ],
                    ),
                  ],
                  if (_clients.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'You can create templates now and assign when clients are connected.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text(
              'Template Library',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              '$unassignedTemplateCount unassigned',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (sortedTemplates.isEmpty)
          const _EmptyCard(text: 'No templates saved yet.')
        else
          ...sortedTemplates.map((template) {
            final templateId =
                int.tryParse('${template['template_id'] ?? ''}') ?? 0;
            final title = (template['title'] ?? '').toString().trim();
            final dayCount = int.tryParse('${template['day_count'] ?? 0}') ?? 0;
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
                int.tryParse('${template['assigned_client_count'] ?? 0}') ?? 0;
            final previewClients = assignedClientsResolved.isNotEmpty
                ? assignedClientsResolved.take(3).toList(growable: false)
                : (assignedClient != null
                      ? <Map<String, dynamic>>[assignedClient]
                      : const <Map<String, dynamic>>[]);
            final assigning = _assigningPlanTemplateIds.contains(templateId);
            final deleting = _deletingPlanTemplateIds.contains(templateId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: templateId <= 0
                    ? null
                    : () => _openTemplatePreviewSheet(template),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _ProgramTag(
                                      icon: Icons.calendar_today_outlined,
                                      label: '$dayCount days',
                                    ),
                                    _ProgramTag(
                                      icon: Icons.fitness_center_outlined,
                                      label: '$exerciseCount exercises',
                                    ),
                                    if (assignedClientCount == 0)
                                      const _ProgramTag(
                                        icon: Icons.hourglass_empty_outlined,
                                        label: 'Not assigned',
                                      )
                                    else
                                      _ProgramTag(
                                        icon: Icons.verified_outlined,
                                        label: '$assignedClientCount assigned',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                onPressed:
                                    (templateId <= 0 || assigning || deleting)
                                    ? null
                                    : () => _openAssignTemplateSheet(template),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  minimumSize: const Size(0, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                                icon: assigning
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: TaqaUiColors.lime,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.group_add_outlined,
                                        size: 18,
                                      ),
                                label: Text(
                                  assigning ? 'Assigning...' : 'Assign',
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Delete template',
                                onPressed:
                                    (templateId <= 0 || assigning || deleting)
                                    ? null
                                    : () => _deletePlanTemplate(template),
                                icon: deleting
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: TaqaUiColors.lime,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (assignedClientCount > 0 &&
                          previewClients.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openAssignedClientsSheet(
                            title.isEmpty ? 'Untitled template' : title,
                            assignedClientsResolved.isNotEmpty
                                ? assignedClientsResolved
                                : previewClients,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                _AssignedClientsStack(
                                  clients: previewClients,
                                  totalCount: assignedClientCount,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    assignedClientCount == 1
                                        ? '1 assigned client'
                                        : '$assignedClientCount assigned clients',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
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
      return Center(
        child: CircularProgressIndicator(color: TaqaUiColors.lime),
      );
    }

    return TaqaRefreshIndicator(
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
                'Coach PIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              if (_loadingCoachPinInSettings)
                const Text(
                  'Loading coach PIN...',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                )
              else if ((_coachPin ?? '').trim().isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.pin_outlined,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (_coachPin ?? '').trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyCoachPinFromSettings,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy'),
                    ),
                  ],
                )
              else
                const Text(
                  'Coach PIN unavailable.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
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
                    : (value) =>
                          setState(() => _autoHabitReminderEnabled = value),
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
                    onSelected: !_autoHabitReminderEnabled || controlsDisabled
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
                    onSelected: !_autoHabitReminderEnabled || controlsDisabled
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
                    decoration: const InputDecoration(labelText: 'Day of week'),
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
                  decoration: const InputDecoration(labelText: 'Hour (0-23)'),
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

  Widget _buildBottomNav() {
    const tabs = <_CoachBottomTab>[
      _CoachBottomTab(
        tabIndex: _tabMyClients,
        label: 'My Clients',
        icon: Icons.people_alt_outlined,
      ),
      _CoachBottomTab(
        tabIndex: _tabPrograms,
        label: 'Programs',
        icon: Icons.fitness_center_outlined,
      ),
      _CoachBottomTab(
        tabIndex: _tabNutrition,
        label: 'Nutrition',
        icon: Icons.restaurant_menu_outlined,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = tab.tabIndex == _tabIndex;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 8 : 3,
                    right: i == tabs.length - 1 ? 8 : 3,
                    top: 8,
                    bottom: 8,
                  ),
                  child: _BottomTabButton(
                    label: tab.label,
                    icon: tab.icon,
                    selected: selected,
                    onTap: () => _selectTab(tab.tabIndex),
                  ),
                ),
              );
            }),
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
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.black,
        titleColor: Colors.white,
        title: _appBarTitle(t),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            IconButton(
              tooltip: 'Settings',
              onPressed: _tabIndex == _tabSettings
                  ? null
                  : () => _selectTab(_tabSettings),
              icon: Icon(
                Icons.settings_outlined,
                color: _tabIndex == _tabSettings
                    ? AppColors.accent
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildMyClientsTab(),
          _buildProgramsTab(),
          _buildNutritionTab(),
          _buildSettingsTab(t),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class _CoachBottomTab {
  const _CoachBottomTab({
    required this.tabIndex,
    required this.label,
    required this.icon,
  });

  final int tabIndex;
  final String label;
  final IconData icon;
}

class _PlanDraftDay {
  _PlanDraftDay({required this.dayLabel, required this.exercises});

  String dayLabel;
  final List<_PlanDraftExercise> exercises;
}

class _PlanDraftExercise {
  _PlanDraftExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.rir,
  });

  int exerciseId;
  int sets;
  int reps;
  int? rir;
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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                  fontSize: 11,
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

class _ProgramStatPill extends StatelessWidget {
  const _ProgramStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramTag extends StatelessWidget {
  const _ProgramTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
  });

  final ProgressionClient client;
  final bool generating;
  final VoidCallback onGenerate;

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
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: generating ? null : onGenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              child: Text(generating ? 'Working...' : 'Generate'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientOverviewCard extends StatelessWidget {
  const _ClientOverviewCard({
    required this.client,
    required this.hasSupportChatUnread,
    required this.reviewCount,
    required this.onView,
  });

  final ProgressionClient client;
  final bool hasSupportChatUnread;
  final int reviewCount;
  final VoidCallback onView;

  bool get _hasAiUpdatesNote =>
      client.hasFormCheckToReview || client.hasUncheckedTrainingPlan;

  IconData get _aiUpdatesIcon => client.hasFormCheckToReview
      ? Icons.notification_important_outlined
      : Icons.auto_awesome_rounded;

  Color get _aiUpdatesColor => client.hasFormCheckToReview
      ? Colors.orangeAccent
      : const Color(0xFF5FD8FF);

  String get _aiUpdatesLabel {
    final hasForm = client.hasFormCheckToReview;
    final hasTraining = client.hasUncheckedTrainingPlan;
    if (hasForm && hasTraining) {
      final total =
          client.sharedFormCheckCount + client.trainingPlanUncheckedCount;
      return total > 1
          ? 'AI updates pending review ($total)'
          : 'AI update pending review';
    }
    if (hasForm) {
      return client.sharedFormCheckCount > 1
          ? 'AI updates: form checks awaiting reply (${client.sharedFormCheckCount})'
          : 'AI updates: form check awaiting reply';
    }
    return client.trainingPlanUncheckedCount > 1
        ? 'AI updates: training suggestions pending review (${client.trainingPlanUncheckedCount})'
        : 'AI updates: training suggestions pending review';
  }

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
                if (hasSupportChatUnread) ...[
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 14,
                        color: Color(0xFF5FD8FF),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'New support chat message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF5FD8FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_hasAiUpdatesNote) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_aiUpdatesIcon, size: 14, color: _aiUpdatesColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _aiUpdatesLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _aiUpdatesColor,
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

class _AssignedClientsStack extends StatelessWidget {
  const _AssignedClientsStack({
    required this.clients,
    required this.totalCount,
  });

  final List<Map<String, dynamic>> clients;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final preview = clients.take(3).toList(growable: false);
    final overflow = totalCount - preview.length;
    final baseWidth = preview.isEmpty ? 0 : (preview.length - 1) * 18 + 30;
    final totalWidth = baseWidth + (overflow > 0 ? 30 : 0);
    return SizedBox(
      width: totalWidth.toDouble(),
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < preview.length; i++)
            Positioned(
              left: i * 18,
              child: _StackClientAvatar(
                name: (preview[i]['name'] ?? '').toString().trim(),
                avatarUrl: (preview[i]['avatar_url'] ?? '').toString().trim(),
                radius: 15,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: baseWidth.toDouble(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  border: Border.all(color: Colors.white30),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StackClientAvatar extends StatelessWidget {
  const _StackClientAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 15,
  });

  final String name;
  final String? avatarUrl;
  final double radius;

  String _initials() {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeAvatarUrlForUi(avatarUrl) ?? '';
    final hasImage = imageUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white10,
      foregroundImage: hasImage ? NetworkImage(imageUrl) : null,
      onForegroundImageError: (_, _) {},
      child: hasImage
          ? null
          : Text(
              _initials(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.5,
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
    final imageUrl = _normalizeAvatarUrlForUi(avatarUrl) ?? '';
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
