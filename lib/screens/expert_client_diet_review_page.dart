import 'package:flutter/material.dart';

import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';

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
  bool _loadingComments = true;
  bool _sendingComment = false;
  final Set<int> _updatingPinnedCommentIds = <int>{};
  final Set<int> _deletingCommentIds = <int>{};
  String? _logError;
  String? _commentsError;
  Map<String, dynamic>? _dietLog;
  List<CoachDietComment> _comments = const [];
  int? _selectedMealId;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dayKey(DateTime.now());
    _loadAll();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

  Future<void> _loadDietLog() async {
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
      final loggedMeals = _loggedMealsFromLog(log);
      if (!mounted) return;
      setState(() {
        _dietLog = log;
        _loadingLog = false;
        _logError = null;
        final selected = _selectedMealId;
        final hasSelected =
            selected != null &&
            loggedMeals.any((meal) => _asInt(meal['meal_id']) == selected);
        _selectedMealId = hasSelected
            ? selected
            : (loggedMeals.isNotEmpty
                  ? _asInt(loggedMeals.first['meal_id'])
                  : null);
      });
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

  Future<void> _loadAll() async {
    await Future.wait([_loadDietLog(), _loadComments()]);
  }

  Future<void> _shiftDay(int delta) async {
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

  Widget _buildSummaryCard() {
    final dietLog = _asMap(_dietLog?['diet_log']);
    final summary = _asMap(dietLog['day_summary']);
    final target = _asMap(summary['target']);
    final consumed = _asMap(summary['consumed']);
    final remaining = _asMap(summary['remaining']);
    final targetCalories = _asInt(target['calories']);
    final consumedCalories = _asInt(consumed['calories']);
    final scorePct = targetCalories > 0
        ? (consumedCalories / targetCalories * 100.0)
        : null;
    final progress = scorePct == null
        ? 0.0
        : ((scorePct / 100.0).clamp(0.0, 1.0)).toDouble();
    final hasSummary = summary.isNotEmpty;

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
            'Daily Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (!hasSummary)
            const Text(
              'No day summary for this date.',
              style: TextStyle(color: Colors.white70),
            )
          else ...[
            _InfoRow(label: 'Target kcal', value: '$targetCalories'),
            const SizedBox(height: 6),
            _InfoRow(label: 'Consumed kcal', value: '$consumedCalories'),
            const SizedBox(height: 6),
            _InfoRow(
              label: 'Remaining kcal',
              value: '${_asInt(remaining['calories'])}',
            ),
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
          ],
        ],
      ),
    );
  }

  Widget _buildMealsCard() {
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
                    : () => setState(() => _selectedMealId = mealId),
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
                            '${_asInt(totals['calories'])} kcal',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
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
                    Text(
                      comment.commentText,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (comment.isPinned) ...[
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Pinned correction',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          const SizedBox(height: 10),
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: selectedMealId == null
                  ? 'Select a logged meal first...'
                  : 'Write feedback for ${_selectedMealLabel()}...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
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
              onPressed: (_sendingComment || selectedMealId == null)
                  ? null
                  : _sendComment,
              icon: const Icon(Icons.send_outlined, size: 16),
              label: Text(_sendingComment ? 'Sending...' : 'Send Comment'),
            ),
          ),
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
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
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
