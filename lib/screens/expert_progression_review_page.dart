import 'package:flutter/material.dart';

import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class ExpertProgressionReviewPage extends StatefulWidget {
  const ExpertProgressionReviewPage({
    super.key,
    required this.reviewId,
  });

  final int reviewId;

  @override
  State<ExpertProgressionReviewPage> createState() =>
      _ExpertProgressionReviewPageState();
}

class _ExpertProgressionReviewPageState
    extends State<ExpertProgressionReviewPage> {
  ProgressionReviewDetail? _review;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final review =
          await ProgressionReviewService.fetchReviewDetail(widget.reviewId);
      if (!mounted) return;
      setState(() => _review = review);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString(),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyReview() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await ProgressionReviewService.applyReview(widget.reviewId);
      if (!mounted) return;
      setState(() => _review = updated);
      AppToast.show(
        context,
        'Progression changes applied to the active program.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approveItem(ProgressionReviewItem item) async {
    await _submitDecision(
      reviewItemId: item.reviewItemId,
      expertDecision: 'approved',
    );
  }

  Future<void> _rejectItem(ProgressionReviewItem item) async {
    await _submitDecision(
      reviewItemId: item.reviewItemId,
      expertDecision: 'rejected',
    );
  }

  Future<void> _editItem(ProgressionReviewItem item) async {
    final setsController = TextEditingController(
      text: (item.finalSets ?? item.aiRecommendedSets).toString(),
    );
    final repsController = TextEditingController(
      text: (item.finalReps ?? item.aiRecommendedReps).toString(),
    );
    final weightController = TextEditingController(
      text: ((item.finalWeightKg ?? item.aiRecommendedWeightKg) ?? 0)
          .toStringAsFixed(1),
    );
    final noteController = TextEditingController(text: item.expertNote ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text(
            'Edit recommendation',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(
                  controller: setsController,
                  label: 'Sets',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _DialogField(
                  controller: repsController,
                  label: 'Reps',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _DialogField(
                  controller: weightController,
                  label: 'Weight (kg)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 10),
                _DialogField(
                  controller: noteController,
                  label: 'Coach note',
                  keyboardType: TextInputType.text,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _submitDecision(
      reviewItemId: item.reviewItemId,
      expertDecision: 'edited',
      finalSets: int.tryParse(setsController.text.trim()),
      finalReps: int.tryParse(repsController.text.trim()),
      finalWeightKg: double.tryParse(weightController.text.trim()),
      expertNote: noteController.text.trim(),
    );
  }

  Future<void> _submitDecision({
    required int reviewItemId,
    required String expertDecision,
    int? finalSets,
    int? finalReps,
    double? finalWeightKg,
    String? expertNote,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final updated = await ProgressionReviewService.updateReviewItem(
        reviewItemId: reviewItemId,
        expertDecision: expertDecision,
        finalSets: finalSets,
        finalReps: finalReps,
        finalWeightKg: finalWeightKg,
        expertNote: expertNote,
      );
      if (!mounted) return;
      setState(() => _review = updated);
      AppToast.show(
        context,
        'Review item updated.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final canApply = review != null &&
        !review.isApplied &&
        review.items.any((item) => item.isApprovedLike);

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(
          review == null
              ? 'Progression Review'
              : 'Review • ${review.weekStart ?? ''}',
        ),
        actions: [
          if (canApply)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: ElevatedButton(
                  onPressed: _saving ? null : _applyReview,
                  child: Text(_saving ? 'Applying...' : 'Apply'),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : review == null
              ? const Center(
                  child: Text(
                    'Review unavailable.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ReviewHeaderCard(review: review),
                      const SizedBox(height: 16),
                      ...review.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ReviewItemCard(
                            item: item,
                            busy: _saving,
                            onApprove: () => _approveItem(item),
                            onReject: () => _rejectItem(item),
                            onEdit: () => _editItem(item),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ReviewHeaderCard extends StatelessWidget {
  const _ReviewHeaderCard({required this.review});

  final ProgressionReviewDetail review;

  Color _statusColor() {
    switch (review.status) {
      case 'applied':
        return AppColors.successGreen;
      case 'failed':
        return AppColors.errorRed;
      case 'pending_expert':
        return Colors.orangeAccent;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.clientName ?? 'Client #${review.userId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _statusColor()),
                ),
                child: Text(
                  review.status,
                  style: TextStyle(
                    color: _statusColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Week ${review.weekStart ?? '-'} to ${review.weekEnd ?? '-'}',
            style: const TextStyle(color: Colors.white70),
          ),
          if ((review.aiSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.aiSummary!,
              style: const TextStyle(color: Colors.white),
            ),
          ],
          if ((review.lastError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.lastError!,
              style: const TextStyle(color: AppColors.errorRed),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  final ProgressionReviewItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  String _fmtWeight(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)} kg';
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finalSets = item.finalSets ?? item.aiRecommendedSets;
    final finalReps = item.finalReps ?? item.aiRecommendedReps;
    final finalWeight = item.finalWeightKg ?? item.aiRecommendedWeightKg;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.expertDecision,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _metricRow(
            'Current',
            '${item.currentSets} sets • ${item.currentReps} reps • ${_fmtWeight(item.currentWeightKg)}',
          ),
          _metricRow(
            'Observed',
            '${item.observedSets ?? '-'} sets • ${item.observedReps ?? '-'} reps • ${_fmtWeight(item.observedWeightKg)} • RIR ${item.observedRir ?? '-'}',
          ),
          _metricRow(
            'AI',
            '${item.aiAction} • ${item.aiRecommendedSets} sets • ${item.aiRecommendedReps} reps • ${_fmtWeight(item.aiRecommendedWeightKg)}',
          ),
          _metricRow(
            'Final',
            '$finalSets sets • $finalReps reps • ${_fmtWeight(finalWeight)}',
          ),
          if ((item.aiReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.aiReason!,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if ((item.expertNote ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Coach note: ${item.expertNote!}',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                    side: const BorderSide(color: AppColors.errorRed),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
