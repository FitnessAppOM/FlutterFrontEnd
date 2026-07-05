import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../services/coach/progression_review_service.dart';
import '../services/coach/voice_note_audio_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/components/taqa_toast.dart';

class ExpertClientDietReviewPage extends StatefulWidget {
  const ExpertClientDietReviewPage({
    super.key,
    required this.clientUserId,
    required this.clientName,
  });

  final int clientUserId;
  final String clientName;

  @override
  State<ExpertClientDietReviewPage> createState() =>
      _ExpertClientDietReviewPageState();
}

class _ExpertClientDietReviewPageState
    extends State<ExpertClientDietReviewPage> {
  final TextEditingController _commentController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _loadingLog = true;
  bool _loadingTargets = true;
  bool _loadingComments = true;
  bool _sendingComment = false;
  bool _sendingVoiceNote = false;
  bool _uploadingDietDocument = false;
  bool _savingTargets = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _voicePlayerSub;
  final Set<int> _updatingPinnedCommentIds = <int>{};
  final Set<int> _deletingCommentIds = <int>{};
  bool _isRecordingVoiceNote = false;
  String? _recordingVoiceNotePath;
  int? _recordingVoiceMealId;
  String? _pendingVoiceNotePath;
  int? _pendingVoiceMealId;
  String? _activeVoiceNoteUrl;
  String? _loadingVoiceNoteUrl;
  String? _logError;
  String? _commentsError;
  String? _targetsError;
  Map<String, dynamic>? _dietLog;
  Map<String, dynamic>? _dietTargets;
  final Map<String, Map<String, dynamic>> _dietLogByDate =
      <String, Map<String, dynamic>>{};
  List<CoachDietComment> _comments = const [];
  int? _selectedMealId;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dayKey(DateTime.now());
    _voicePlayerSub = _voicePlayer.playerStateStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _voicePlayerSub?.cancel();
    unawaited(_voicePlayer.dispose());
    unawaited(_audioRecorder.dispose());
    _commentController.dispose();
    final pendingPath = (_pendingVoiceNotePath ?? '').trim();
    if (pendingPath.isNotEmpty) {
      unawaited(_deleteLocalFile(pendingPath));
    }
    super.dispose();
  }

  DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateToken(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _prettyDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _loggedMealsFromLog(Map<String, dynamic>? rawLog) {
    final dietLog = _asMap(rawLog?['diet_log']);
    final meals = _asMapList(dietLog['meals']);
    return meals.where((meal) => _asMapList(meal['items']).isNotEmpty).toList();
  }

  String _mealLabel(Map<String, dynamic> meal) {
    final title = (meal['title'] ?? '').toString().trim();
    if (title.isNotEmpty) return title;
    final index = _asInt(meal['meal_index']);
    if (index > 0) return 'Meal $index';
    return 'Meal';
  }

  String _selectedMealLabel() {
    final selected = _selectedMealId;
    if (selected == null) return 'selected meal';
    final meal = _loggedMealsFromLog(_dietLog).firstWhere(
      (entry) => _asInt(entry['meal_id']) == selected,
      orElse: () => const <String, dynamic>{},
    );
    if (meal.isEmpty) return 'selected meal';
    return _mealLabel(meal);
  }

  String _normalizeVoiceNoteUrl(String? rawUrl) => (rawUrl ?? '').trim();

  String _pendingVoiceSourceKey(String path) => 'local:${path.trim()}';

  bool _isVoiceNoteLoading(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    return _loadingVoiceNoteUrl == normalized;
  }

  bool _isVoiceNotePlaying(String? rawUrl) {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return false;
    if (_activeVoiceNoteUrl != normalized) return false;
    return _voicePlayer.playing &&
        _voicePlayer.processingState != ProcessingState.completed;
  }

  Future<void> _toggleVoiceNotePlayback(String? rawUrl) async {
    final normalized = _normalizeVoiceNoteUrl(rawUrl);
    if (normalized.isEmpty) return;

    if (_activeVoiceNoteUrl == normalized) {
      if (_voicePlayer.processingState == ProcessingState.completed) {
        await _voicePlayer.seek(Duration.zero);
        await _voicePlayer.play();
        return;
      }
      if (_voicePlayer.playing) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play();
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingVoiceNoteUrl = normalized);
    } else {
      _loadingVoiceNoteUrl = normalized;
    }
    try {
      await _voicePlayer.stop();
      final localPath = await VoiceNoteAudioService.prepareLocalVoiceNoteFile(
        normalized,
      );
      await _voicePlayer.setFilePath(localPath);
      if (mounted) {
        setState(() {
          _activeVoiceNoteUrl = normalized;
        });
      } else {
        _activeVoiceNoteUrl = normalized;
      }
      await _voicePlayer.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingVoiceNoteUrl == normalized) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else if (_loadingVoiceNoteUrl == normalized) {
        _loadingVoiceNoteUrl = null;
      }
    }
  }

  Future<void> _togglePendingVoicePlayback(String localPath) async {
    final normalizedPath = localPath.trim();
    if (normalizedPath.isEmpty) return;
    final sourceKey = _pendingVoiceSourceKey(normalizedPath);

    if (_activeVoiceNoteUrl == sourceKey) {
      if (_voicePlayer.processingState == ProcessingState.completed) {
        await _voicePlayer.seek(Duration.zero);
        await _voicePlayer.play();
        return;
      }
      if (_voicePlayer.playing) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play();
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingVoiceNoteUrl = sourceKey);
    } else {
      _loadingVoiceNoteUrl = sourceKey;
    }

    try {
      await _voicePlayer.stop();
      await _voicePlayer.setFilePath(normalizedPath);
      if (mounted) {
        setState(() {
          _activeVoiceNoteUrl = sourceKey;
        });
      } else {
        _activeVoiceNoteUrl = sourceKey;
      }
      await _voicePlayer.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingVoiceNoteUrl == sourceKey) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else if (_loadingVoiceNoteUrl == sourceKey) {
        _loadingVoiceNoteUrl = null;
      }
    }
  }

  bool _hasPendingVoiceNoteForSelectedMeal() {
    final mealId = _selectedMealId;
    if (mealId == null) return false;
    if (_pendingVoiceMealId != mealId) return false;
    return (_pendingVoiceNotePath ?? '').trim().isNotEmpty;
  }

  Future<void> _deleteLocalFile(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    try {
      final file = File(normalized);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> _requestMicrophonePermission() async {
    try {
      final allowedByRecorder = await _audioRecorder.hasPermission();
      if (allowedByRecorder) return true;
    } catch (_) {}
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied || status.isRestricted) return false;
      status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearPendingVoiceNote({bool deleteFile = true}) async {
    final pendingPath = (_pendingVoiceNotePath ?? '').trim();
    final pendingKey = pendingPath.isEmpty
        ? null
        : _pendingVoiceSourceKey(pendingPath);
    if (pendingKey != null && _activeVoiceNoteUrl == pendingKey) {
      try {
        await _voicePlayer.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _activeVoiceNoteUrl = null;
          if (_loadingVoiceNoteUrl == pendingKey) {
            _loadingVoiceNoteUrl = null;
          }
        });
      } else {
        _activeVoiceNoteUrl = null;
        if (_loadingVoiceNoteUrl == pendingKey) {
          _loadingVoiceNoteUrl = null;
        }
      }
    }
    if (mounted) {
      setState(() {
        _pendingVoiceMealId = null;
        _pendingVoiceNotePath = null;
      });
    } else {
      _pendingVoiceMealId = null;
      _pendingVoiceNotePath = null;
    }
    if (deleteFile && pendingPath.isNotEmpty) {
      await _deleteLocalFile(pendingPath);
    }
  }

  void _applyDietLogState(Map<String, dynamic> log) {
    final loggedMeals = _loggedMealsFromLog(log);
    final selected = _selectedMealId;
    final hasSelected =
        selected != null &&
        loggedMeals.any((meal) => _asInt(meal['meal_id']) == selected);
    _dietLog = log;
    _loadingLog = false;
    _logError = null;
    _selectedMealId = hasSelected
        ? selected
        : (loggedMeals.isNotEmpty
              ? _asInt(loggedMeals.first['meal_id'])
              : null);
  }

  Future<void> _loadDietLog({bool forceRefresh = false}) async {
    final dateKey = _dateToken(_selectedDate);
    if (!forceRefresh) {
      final cached = _dietLogByDate[dateKey];
      if (cached != null) {
        if (!mounted) return;
        setState(() => _applyDietLogState(cached));
        return;
      }
    }
    if (mounted) {
      setState(() {
        _loadingLog = true;
        _logError = null;
      });
    }
    try {
      final log = await ProgressionReviewService.fetchClientDietLog(
        clientUserId: widget.clientUserId,
        mealDate: _selectedDate,
      );
      _dietLogByDate[dateKey] = log;
      if (!mounted) return;
      setState(() => _applyDietLogState(log));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLog = false;
        _dietLog = null;
        _selectedMealId = null;
        _logError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> _trainingDayTargets() {
    final raw = _dietTargets?['training_day_targets'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  int? _parsePositiveIntOrNull(String rawValue) {
    final value = int.tryParse(rawValue.trim());
    if (value == null) return null;
    if (value < 0) return null;
    return value;
  }

  Future<void> _loadDietTargets() async {
    if (mounted) {
      setState(() {
        _loadingTargets = true;
        _targetsError = null;
      });
    }
    try {
      final targets = await ProgressionReviewService.fetchClientDietTargets(
        clientUserId: widget.clientUserId,
        autoGenerate: true,
      );
      if (!mounted) return;
      setState(() {
        _dietTargets = targets;
        _loadingTargets = false;
        _targetsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dietTargets = null;
        _loadingTargets = false;
        _targetsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openEditTargetsSheet() async {
    if (_dietTargets == null || _loadingTargets || _savingTargets) return;

    final restCalCtrl = TextEditingController(
      text: '${_asInt(_dietTargets?['rest_calories'])}',
    );
    final restPCtrl = TextEditingController(
      text: '${_asInt(_dietTargets?['rest_protein_g'])}',
    );
    final restCCtrl = TextEditingController(
      text: '${_asInt(_dietTargets?['rest_carbs_g'])}',
    );
    final restFCtrl = TextEditingController(
      text: '${_asInt(_dietTargets?['rest_fat_g'])}',
    );

    final dayControllers = <int, Map<String, TextEditingController>>{};
    for (final day in _trainingDayTargets()) {
      final dayId = _asInt(day['day_id']);
      if (dayId <= 0) continue;
      dayControllers[dayId] = {
        'cal': TextEditingController(text: '${_asInt(day['train_calories'])}'),
        'p': TextEditingController(text: '${_asInt(day['train_protein_g'])}'),
        'c': TextEditingController(text: '${_asInt(day['train_carbs_g'])}'),
        'f': TextEditingController(text: '${_asInt(day['train_fat_g'])}'),
      };
    }
    void disposeControllers() {
      restCalCtrl.dispose();
      restPCtrl.dispose();
      restCCtrl.dispose();
      restFCtrl.dispose();
      for (final ctrls in dayControllers.values) {
        for (final ctrl in ctrls.values) {
          ctrl.dispose();
        }
      }
    }

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Edit Client Targets',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D7CFF).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2D7CFF).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Note: Client-visible calorie targets may appear higher than entered values for today because burned calories are added automatically.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rest day',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: restCalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Kcal'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: restPCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'P (g)'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: restCCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'C (g)'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: restFCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'F (g)'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_trainingDayTargets().isNotEmpty) ...[
                    const Text(
                      'Training days',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final day in _trainingDayTargets()) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (day['day_label'] ?? '').toString().trim().isEmpty
                                  ? 'Day ${_asInt(day['day_id'])}'
                                  : (day['day_label'] ?? '').toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        dayControllers[_asInt(
                                          day['day_id'],
                                        )]?['cal'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Kcal',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        dayControllers[_asInt(
                                          day['day_id'],
                                        )]?['p'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'P (g)',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller:
                                        dayControllers[_asInt(
                                          day['day_id'],
                                        )]?['c'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'C (g)',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller:
                                        dayControllers[_asInt(
                                          day['day_id'],
                                        )]?['f'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'F (g)',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Targets'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
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

    if (shouldSubmit != true || !mounted) {
      disposeControllers();
      return;
    }

    final restPayload = <String, dynamic>{
      'calories': _parsePositiveIntOrNull(restCalCtrl.text),
      'protein_g': _parsePositiveIntOrNull(restPCtrl.text),
      'carbs_g': _parsePositiveIntOrNull(restCCtrl.text),
      'fat_g': _parsePositiveIntOrNull(restFCtrl.text),
    };
    if (restPayload.values.any((value) => value == null)) {
      AppToast.show(
        context,
        'Please enter valid non-negative numbers.',
        type: AppToastType.info,
      );
      disposeControllers();
      return;
    }

    final trainingPayload = <Map<String, dynamic>>[];
    for (final day in _trainingDayTargets()) {
      final dayId = _asInt(day['day_id']);
      if (dayId <= 0) continue;
      final ctrls = dayControllers[dayId];
      final cal = _parsePositiveIntOrNull(ctrls?['cal']?.text ?? '');
      final p = _parsePositiveIntOrNull(ctrls?['p']?.text ?? '');
      final c = _parsePositiveIntOrNull(ctrls?['c']?.text ?? '');
      final f = _parsePositiveIntOrNull(ctrls?['f']?.text ?? '');
      if (cal == null || p == null || c == null || f == null) {
        AppToast.show(
          context,
          'Please enter valid numbers for all training days.',
          type: AppToastType.info,
        );
        disposeControllers();
        return;
      }
      trainingPayload.add({
        'day_id': dayId,
        'calories': cal,
        'protein_g': p,
        'carbs_g': c,
        'fat_g': f,
      });
    }

    setState(() => _savingTargets = true);
    try {
      final updated = await ProgressionReviewService.patchClientDietTargets(
        clientUserId: widget.clientUserId,
        rest: restPayload,
        trainingDays: trainingPayload,
      );
      if (!mounted) return;
      setState(() {
        _dietTargets = updated;
        _targetsError = null;
      });
      await _loadDietLog(forceRefresh: true);
      if (!mounted) return;
      AppToast.show(
        context,
        'Diet targets updated for client.',
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
      disposeControllers();
      if (mounted) setState(() => _savingTargets = false);
    }
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _loadingComments = true;
        _commentsError = null;
      });
    }
    try {
      final comments = await ProgressionReviewService.fetchClientDietComments(
        clientUserId: widget.clientUserId,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadingComments = false;
        _commentsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _comments = const [];
        _loadingComments = false;
        _commentsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadAll({bool forceRefresh = false}) async {
    await Future.wait([
      _loadDietLog(forceRefresh: forceRefresh),
      _loadDietTargets(),
      _loadComments(),
    ]);
  }

  Future<void> _shiftDay(int delta) async {
    if (_isRecordingVoiceNote ||
        (_pendingVoiceNotePath ?? '').trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finish or cancel the current voice note before changing date.',
          ),
        ),
      );
      return;
    }
    final next = _dayKey(
      DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + delta,
      ),
    );
    final today = _dayKey(DateTime.now());
    if (next.isAfter(today)) return;
    setState(() {
      _selectedDate = next;
      _selectedMealId = null;
    });
    await _loadDietLog();
  }

  Future<bool> _startVoiceNoteRecording() async {
    final mealId = _selectedMealId;
    if (mealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a logged meal before recording.')),
      );
      return false;
    }
    if (_sendingVoiceNote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice note is still uploading.')),
      );
      return false;
    }
    if ((_pendingVoiceNotePath ?? '').trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send or cancel the pending voice note first.'),
        ),
      );
      return false;
    }
    if (_isRecordingVoiceNote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A voice note is already recording.')),
      );
      return false;
    }
    final hasPermission = await _requestMicrophonePermission();
    if (!mounted) return false;
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission is required. Enable it in app settings.',
          ),
        ),
      );
      return false;
    }
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/diet_voice_note_${widget.clientUserId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not start recording: $e')));
      return false;
    }
    if (!mounted) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      return false;
    }
    setState(() {
      _isRecordingVoiceNote = true;
      _recordingVoiceMealId = mealId;
      _recordingVoiceNotePath = path;
    });
    return true;
  }

  Future<bool> _stopVoiceNoteRecording({bool showHint = true}) async {
    final mealId = _selectedMealId;
    if (!_isRecordingVoiceNote || _recordingVoiceMealId != mealId) {
      return false;
    }
    String? recordedPath;
    try {
      recordedPath = await _audioRecorder.stop();
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not finish voice recording.')),
      );
      return false;
    }
    final audioPath = (recordedPath ?? _recordingVoiceNotePath ?? '').trim();
    if (mounted) {
      setState(() {
        _isRecordingVoiceNote = false;
        _recordingVoiceMealId = null;
        _recordingVoiceNotePath = null;
      });
    } else {
      _isRecordingVoiceNote = false;
      _recordingVoiceMealId = null;
      _recordingVoiceNotePath = null;
    }
    if (audioPath.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No voice note was recorded.')),
      );
      return false;
    }
    if (mounted) {
      setState(() {
        _pendingVoiceMealId = mealId;
        _pendingVoiceNotePath = audioPath;
      });
      if (showHint) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording stopped. Send or cancel.')),
        );
      }
    } else {
      _pendingVoiceMealId = mealId;
      _pendingVoiceNotePath = audioPath;
    }
    return true;
  }

  Future<void> _sendPendingVoiceNote() async {
    final mealId = _selectedMealId;
    if (mealId == null || !_hasPendingVoiceNoteForSelectedMeal()) return;
    if (_sendingVoiceNote) return;
    final audioPath = (_pendingVoiceNotePath ?? '').trim();
    if (audioPath.isEmpty) return;
    setState(() => _sendingVoiceNote = true);
    try {
      final created = await ProgressionReviewService.addClientDietVoiceNote(
        clientUserId: widget.clientUserId,
        mealDate: _selectedDate,
        mealId: mealId,
        audioFilePath: audioPath,
        commentText: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _comments = [created, ..._comments];
      });
      await _clearPendingVoiceNote(deleteFile: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Voice note sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingVoiceNote = false);
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final mealId = _selectedMealId;
    if (text.isEmpty || _sendingComment) return;
    if (mealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a logged meal before commenting.'),
        ),
      );
      return;
    }
    setState(() => _sendingComment = true);
    try {
      final created = await ProgressionReviewService.addClientDietComment(
        clientUserId: widget.clientUserId,
        mealDate: _selectedDate,
        mealId: mealId,
        commentText: text,
      );
      if (!mounted) return;
      _commentController.clear();
      setState(() {
        _comments = [created, ..._comments];
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diet comment sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _handlePrimarySend() async {
    if (_sendingComment || _sendingVoiceNote) return;
    final mealId = _selectedMealId;
    if (mealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a logged meal before commenting.'),
        ),
      );
      return;
    }

    if (_isRecordingVoiceNote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop recording before sending.')),
      );
      return;
    }

    if (_hasPendingVoiceNoteForSelectedMeal()) {
      await _sendPendingVoiceNote();
      return;
    }

    final text = _commentController.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write your comment before sending.')),
      );
      return;
    }
    await _sendComment();
  }

  Future<void> _handleCommentSubmitted(String rawValue) async {
    if (!mounted) return;
    final text = rawValue.trim();
    if (text.isEmpty) {
      FocusScope.of(context).unfocus();
      return;
    }
    await _handlePrimarySend();
  }

  Future<void> _toggleCommentPin(CoachDietComment comment) async {
    if (_updatingPinnedCommentIds.contains(comment.commentId)) return;
    setState(() => _updatingPinnedCommentIds.add(comment.commentId));
    try {
      final updated = await ProgressionReviewService.setClientDietCommentPinned(
        clientUserId: widget.clientUserId,
        commentId: comment.commentId,
        isPinned: !comment.isPinned,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .map((item) => item.commentId == updated.commentId ? updated : item)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingPinnedCommentIds.remove(comment.commentId));
      }
    }
  }

  Future<void> _deleteComment(CoachDietComment comment) async {
    if (_deletingCommentIds.contains(comment.commentId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This will remove the comment for the client.'),
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
    setState(() => _deletingCommentIds.add(comment.commentId));
    try {
      await ProgressionReviewService.deleteClientDietComment(
        clientUserId: widget.clientUserId,
        commentId: comment.commentId,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments
            .where((item) => item.commentId != comment.commentId)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingCommentIds.remove(comment.commentId));
      }
    }
  }

  Future<void> _uploadDietDocument() async {
    if (_uploadingDietDocument) return;
    setState(() => _uploadingDietDocument = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        withData: false,
      );
      final files = picked?.files ?? const <PlatformFile>[];
      final file = files.isEmpty ? null : files.first;
      final path = (file?.path ?? '').trim();
      if (path.isEmpty) return;
      final size = file?.size ?? 0;
      if (size > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document must be 10 MB or smaller.')),
        );
        return;
      }

      final uploaded = await ProgressionReviewService.uploadClientDietDocument(
        clientUserId: widget.clientUserId,
        documentFilePath: path,
        documentTitle: file?.name,
      );
      if (!mounted) return;
      final title =
          (uploaded.documentTitle ?? uploaded.originalFilename ?? 'Document')
              .trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded "$title" (${_formatBytes(uploaded.fileSizeBytes)}).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _uploadingDietDocument = false);
    }
  }

  Widget _buildSummaryCard() {
    final dietLog = _asMap(_dietLog?['diet_log']);
    final summary = _asMap(dietLog['day_summary']);
    final target = _asMap(summary['target']);
    final consumed = _asMap(summary['consumed']);
    final remaining = _asMap(summary['remaining']);
    final dayType = (summary['day_type'] ?? '').toString().trim().toLowerCase();
    final dayTypeLabel = dayType == 'training'
        ? 'Training day'
        : (dayType == 'rest' ? 'Rest day' : '-');
    final targetCalories = _asInt(target['calories']);
    final consumedCalories = _asInt(consumed['calories']);
    final remainingCalories = _asInt(remaining['calories']);
    final targetProtein = _asInt(target['protein_g']);
    final consumedProtein = _asInt(consumed['protein_g']);
    final remainingProtein = _asInt(remaining['protein_g']);
    final targetCarbs = _asInt(target['carbs_g']);
    final consumedCarbs = _asInt(consumed['carbs_g']);
    final remainingCarbs = _asInt(remaining['carbs_g']);
    final targetFat = _asInt(target['fat_g']);
    final consumedFat = _asInt(consumed['fat_g']);
    final remainingFat = _asInt(remaining['fat_g']);
    final scorePct = targetCalories > 0
        ? (consumedCalories / targetCalories * 100.0)
        : null;
    final progress = scorePct == null
        ? 0.0
        : ((scorePct / 100.0).clamp(0.0, 1.0)).toDouble();
    final hasSummary = summary.isNotEmpty;
    final createdBy = (_dietTargets?['created_by'] ?? '').toString().trim();
    final updatedAt = (_dietTargets?['updated_at'] ?? '').toString().trim();

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: (_loadingTargets || _savingTargets)
                    ? null
                    : _openEditTargetsSheet,
                tooltip: 'Edit client diet targets',
                icon: _savingTargets
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.tune, color: Colors.white70, size: 18),
              ),
            ],
          ),
          if (_targetsError != null) ...[
            const SizedBox(height: 6),
            Text(
              _targetsError!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ],
          if (createdBy.isNotEmpty || updatedAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (createdBy.isNotEmpty) 'Source: ${createdBy.toUpperCase()}',
                if (updatedAt.isNotEmpty) 'Updated: $updatedAt',
              ].join(' • '),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          if (!hasSummary)
            const Text(
              'No day summary for this date.',
              style: TextStyle(color: Colors.white70),
            )
          else ...[
            _InfoRow(label: 'Day type', value: dayTypeLabel),
            const SizedBox(height: 6),
            _InfoRow(label: 'Target kcal', value: '$targetCalories'),
            const SizedBox(height: 6),
            _InfoRow(label: 'Consumed kcal', value: '$consumedCalories'),
            const SizedBox(height: 6),
            _InfoRow(label: 'Remaining kcal', value: '$remainingCalories'),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Goal done',
              value: targetCalories > 0
                  ? '$consumedCalories / $targetCalories kcal'
                  : '-',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Goal score',
              value: scorePct == null ? '-' : '${scorePct.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Target vs consumed',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            _MacroProgressRow(
              label: 'Calories',
              consumed: consumedCalories,
              target: targetCalories,
              remaining: remainingCalories,
              unit: 'kcal',
            ),
            const SizedBox(height: 6),
            _MacroProgressRow(
              label: 'Protein',
              consumed: consumedProtein,
              target: targetProtein,
              remaining: remainingProtein,
              unit: 'g',
            ),
            const SizedBox(height: 6),
            _MacroProgressRow(
              label: 'Carbs',
              consumed: consumedCarbs,
              target: targetCarbs,
              remaining: remainingCarbs,
              unit: 'g',
            ),
            const SizedBox(height: 6),
            _MacroProgressRow(
              label: 'Fat',
              consumed: consumedFat,
              target: targetFat,
              remaining: remainingFat,
              unit: 'g',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealsCard() {
    final daySummary = _asMap(_asMap(_dietLog?['diet_log'])['day_summary']);
    final dayTarget = _asMap(daySummary['target']);
    final dayTargetCalories = _asInt(dayTarget['calories']);
    final dayTargetProtein = _asInt(dayTarget['protein_g']);
    final dayTargetCarbs = _asInt(dayTarget['carbs_g']);
    final dayTargetFat = _asInt(dayTarget['fat_g']);
    final meals = _loggedMealsFromLog(_dietLog);

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
          const Text(
            'Logged Meals (Select One)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coach comments are attached to the selected meal.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (dayTarget.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Day target: $dayTargetCalories kcal • P $dayTargetProtein g • C $dayTargetCarbs g • F $dayTargetFat g',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (meals.isEmpty)
            const Text(
              'No logged meals found for this date.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ...meals.map((meal) {
              final mealId = _asInt(meal['meal_id']);
              final mealLabel = _mealLabel(meal);
              final totals = _asMap(meal['totals']);
              final mealCalories = _asInt(totals['calories']);
              final mealProtein = _asInt(totals['protein_g']);
              final mealCarbs = _asInt(totals['carbs_g']);
              final mealFat = _asInt(totals['fat_g']);
              final mealCaloriesScore = dayTargetCalories > 0
                  ? (mealCalories / dayTargetCalories * 100.0)
                  : null;
              final items = _asMapList(meal['items']);
              final isSelected = mealId > 0 && mealId == _selectedMealId;
              final previewItems = items
                  .take(3)
                  .map((item) {
                    final itemName = (item['item_name'] ?? '')
                        .toString()
                        .trim();
                    if (itemName.isEmpty) return null;
                    return itemName;
                  })
                  .whereType<String>()
                  .toList();
              return InkWell(
                onTap: mealId <= 0
                    ? null
                    : () {
                        if (_isRecordingVoiceNote ||
                            (_pendingVoiceNotePath ?? '').trim().isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Finish or cancel the current voice note before changing meal.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _selectedMealId = mealId);
                      },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.accent : Colors.white12,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mealLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle,
                                size: 18,
                                color: AppColors.accent,
                              ),
                            ),
                          Text(
                            mealCaloriesScore == null
                                ? '$mealCalories kcal'
                                : '$mealCalories kcal (${mealCaloriesScore.toStringAsFixed(0)}%)',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'P $mealProtein g • C $mealCarbs g • F $mealFat g',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.length} item(s)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (previewItems.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          previewItems.join(' • '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
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
    );
  }

  Widget _buildCommentsCard() {
    final selectedDateToken = _dateToken(_selectedDate);
    final selectedMealId = _selectedMealId;
    final commentsForDate = _comments
        .where((item) => item.mealDate.trim() == selectedDateToken)
        .where(
          (item) => selectedMealId == null || item.mealId == selectedMealId,
        )
        .toList();
    commentsForDate.sort((a, b) {
      final aTs = a.createdAt ?? a.updatedAt;
      final bTs = b.createdAt ?? b.updatedAt;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    final isSaving = _sendingComment;
    final isSendingVoice = _sendingVoiceNote;
    final isRecordingVoice =
        _isRecordingVoiceNote && _recordingVoiceMealId == selectedMealId;
    final hasPendingVoice = _hasPendingVoiceNoteForSelectedMeal();
    final pendingVoicePath = hasPendingVoice
        ? (_pendingVoiceNotePath ?? '').trim()
        : '';
    final pendingVoiceKey = pendingVoicePath.isEmpty
        ? ''
        : _pendingVoiceSourceKey(pendingVoicePath);
    final isPendingVoiceLoading =
        pendingVoiceKey.isNotEmpty && _isVoiceNoteLoading(pendingVoiceKey);
    final isPendingVoicePlaying =
        pendingVoiceKey.isNotEmpty && _isVoiceNotePlaying(pendingVoiceKey);
    final isAnySending = isSaving || isSendingVoice;

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
          const Text(
            'Coach Notes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 6,
            textInputAction: TextInputAction.send,
            style: const TextStyle(color: Colors.white),
            onSubmitted: _handleCommentSubmitted,
            decoration: InputDecoration(
              hintText: selectedMealId == null
                  ? 'Select a logged meal first...'
                  : 'Write review notes for the client...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.icon(
                onPressed:
                    (isAnySending ||
                        selectedMealId == null ||
                        _isRecordingVoiceNote)
                    ? null
                    : _handlePrimarySend,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
                icon: isAnySending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 14),
                label: Text(isAnySending ? 'Sending...' : 'Send'),
              ),
              const SizedBox(width: 8),
              if (isRecordingVoice)
                OutlinedButton.icon(
                  onPressed: (isSaving || isSendingVoice)
                      ? null
                      : _stopVoiceNoteRecording,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.stop, size: 14),
                  label: const Text('Stop'),
                )
              else if (hasPendingVoice) ...[
                TextButton.icon(
                  onPressed:
                      (isSaving || isSendingVoice || pendingVoicePath.isEmpty)
                      ? null
                      : () => _togglePendingVoicePlayback(pendingVoicePath),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3,
                    ),
                  ),
                  icon: isPendingVoiceLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        )
                      : Icon(
                          isPendingVoicePlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          size: 16,
                        ),
                  label: Text(
                    isPendingVoicePlaying ? 'Pause preview' : 'Play preview',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: (isSaving || isSendingVoice)
                      ? null
                      : () => _clearPendingVoiceNote(deleteFile: true),
                  child: const Text('Cancel'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed:
                      (isSaving || isSendingVoice || selectedMealId == null)
                      ? null
                      : _startVoiceNoteRecording,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                  ),
                  icon: const Icon(Icons.mic, size: 14),
                  label: const Text('Record voice'),
                ),
            ],
          ),
          if (isRecordingVoice) ...[
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(
                  Icons.fiber_manual_record,
                  size: 10,
                  color: Colors.redAccent,
                ),
                SizedBox(width: 6),
                Text(
                  'Recording...',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                _AudioWaveBars(
                  color: Colors.redAccent,
                  barCount: 6,
                  minHeight: 4,
                  maxHeight: 14,
                  barWidth: 3,
                  gap: 2,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_loadingComments)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_commentsError != null)
            Text(_commentsError!, style: const TextStyle(color: Colors.white70))
          else if (selectedMealId == null)
            const Text(
              'Select a logged meal to view and add comments.',
              style: TextStyle(color: Colors.white70),
            )
          else if (commentsForDate.isEmpty)
            Text(
              'No comments for ${_selectedMealLabel()} yet.',
              style: const TextStyle(color: Colors.white70),
            )
          else
            ...commentsForDate.map((comment) {
              final isPinUpdating = _updatingPinnedCommentIds.contains(
                comment.commentId,
              );
              final isDeleting = _deletingCommentIds.contains(
                comment.commentId,
              );
              final hasVoiceNote = _normalizeVoiceNoteUrl(
                comment.voiceNoteUrl,
              ).isNotEmpty;
              final isVoiceLoading = _isVoiceNoteLoading(comment.voiceNoteUrl);
              final isVoicePlaying = _isVoiceNotePlaying(comment.voiceNoteUrl);
              final text = comment.commentText.trim();
              final seenByClient = comment.clientSeenAt != null;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDateTime(
                              comment.createdAt ?? comment.updatedAt,
                            ),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: (isPinUpdating || isDeleting)
                              ? null
                              : () => _toggleCommentPin(comment),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: comment.isPinned
                                ? Colors.orangeAccent
                                : Colors.white70,
                            side: BorderSide(
                              color: comment.isPinned
                                  ? Colors.orangeAccent
                                  : Colors.white24,
                            ),
                            minimumSize: const Size(0, 26),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                          ),
                          icon: isPinUpdating
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              : Icon(
                                  comment.isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 12,
                                ),
                          label: Text(comment.isPinned ? 'Unpin' : 'Pin'),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: (isPinUpdating || isDeleting)
                              ? null
                              : () => _deleteComment(comment),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 26),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -3,
                            ),
                          ),
                          icon: isDeleting
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                )
                              : const Icon(Icons.delete_outline, size: 12),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if ((comment.mealTitle ?? '').trim().isNotEmpty)
                      const SizedBox(height: 4),
                    if ((comment.mealTitle ?? '').trim().isNotEmpty)
                      Text(
                        comment.mealTitle!.trim(),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (text.isNotEmpty)
                      Text(text, style: const TextStyle(color: Colors.white70))
                    else if (hasVoiceNote)
                      const Text(
                        'Voice note from coach.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          seenByClient ? 'Seen' : 'Unseen',
                          style: TextStyle(
                            color: seenByClient
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (hasVoiceNote)
                          TextButton.icon(
                            onPressed: isVoiceLoading
                                ? null
                                : () => _toggleVoiceNotePlayback(
                                    comment.voiceNoteUrl,
                                  ),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 26),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -3,
                              ),
                            ),
                            icon: isVoiceLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  )
                                : Icon(
                                    isVoicePlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                            label: Text(
                              isVoicePlaying ? 'Pause voice' : 'Play voice',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _dayKey(DateTime.now());
    final canGoNext = _selectedDate.isBefore(today);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text('${widget.clientName} • Diet Review'),
        actions: [
          TextButton.icon(
            onPressed: _uploadingDietDocument ? null : _uploadDietDocument,
            icon: _uploadingDietDocument
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            label: Text(
              _uploadingDietDocument ? 'Uploading...' : 'Upload a plan',
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAll(forceRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _loadingLog ? null : () => _shiftDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      _prettyDate(_selectedDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: (_loadingLog || !canGoNext)
                        ? null
                        : () => _shiftDay(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingLog)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_logError != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _logError!,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            else ...[
              _buildSummaryCard(),
              const SizedBox(height: 12),
              _buildMealsCard(),
            ],
            const SizedBox(height: 12),
            _buildCommentsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MacroProgressRow extends StatelessWidget {
  const _MacroProgressRow({
    required this.label,
    required this.consumed,
    required this.target,
    required this.remaining,
    required this.unit,
  });

  final String label;
  final int consumed;
  final int target;
  final int remaining;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final score = target > 0 ? (consumed / target * 100.0) : null;
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            '$consumed / $target $unit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          'Rem $remaining $unit${score == null ? '' : ' • ${score.toStringAsFixed(0)}%'}',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AudioWaveBars extends StatefulWidget {
  const _AudioWaveBars({
    required this.color,
    this.barCount = 5,
    this.minHeight = 4,
    this.maxHeight = 12,
    this.barWidth = 3,
    this.gap = 2,
  });

  final Color color;
  final int barCount;
  final double minHeight;
  final double maxHeight;
  final double barWidth;
  final double gap;

  @override
  State<_AudioWaveBars> createState() => _AudioWaveBarsState();
}

class _AudioWaveBarsState extends State<_AudioWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(widget.barCount, (index) {
            final phase = t + (index * 0.7);
            final level = (math.sin(phase) + 1) / 2;
            final height =
                widget.minHeight +
                (widget.maxHeight - widget.minHeight) * level;
            return Padding(
              padding: EdgeInsets.only(
                right: index == widget.barCount - 1 ? 0 : widget.gap,
              ),
              child: Container(
                width: widget.barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
