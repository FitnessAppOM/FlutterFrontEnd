import 'package:flutter/material.dart';

import '../core/user_friendly_error.dart';
import '../services/coach/progression_review_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_expert_client_dashboard_ui.dart';
import '../TaqaUI/components/taqa_filled_button.dart';
import '../TaqaUI/components/taqa_loading_indicator.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/components/taqa_value_dialog.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/taqa_ui_colors.dart';

const Color _successGreen = Color(0xFF2E8B57);

class ExpertProgressionReviewPage extends StatefulWidget {
  const ExpertProgressionReviewPage({super.key, required this.reviewId});

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
      final review = await ProgressionReviewService.fetchReviewDetail(
        widget.reviewId,
      );
      if (!mounted) return;
      setState(() => _review = review);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _applyReview() async {
    if (_saving) return;
    final review = _review;
    if (review == null) return;

    // Applying locks the review, so anything still undecided is dropped for
    // good. Never let that happen silently.
    final pending = review.pendingItemCount;
    final applying = review.items.where((item) => item.isApprovedLike).length;
    if (pending > 0) {
      final proceed = await _confirmApply(
        applying: applying,
        pending: pending,
      );
      if (proceed != true) return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ProgressionReviewService.applyReview(
        widget.reviewId,
        skipPending: pending > 0,
      );
      if (!mounted) return;
      setState(() => _review = updated);
      AppToast.show(
        context,
        'AI updates applied to the active program.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmApply({
    required int applying,
    required int pending,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) => TaqaPopupDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                'Apply to Program',
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  fontSize: TaqaUiScale.sp(15),
                  fontWeight: FontWeight.w700,
                  height: 25 / 15,
                  color: TaqaUiColors.charcoal,
                ),
              ),
            ),
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaClientDashboardBodyText(
              '$applying ${applying == 1 ? 'change' : 'changes'} will be sent to '
              'the client. $pending undecided '
              '${pending == 1 ? 'suggestion' : 'suggestions'} will be skipped '
              'and can no longer be reviewed.',
            ),
            SizedBox(height: TaqaUiScale.h(20)),
            SizedBox(
              height: TaqaUiScale.h(45),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Center(
                        child: Text(
                          'CANCEL',
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
                  Expanded(
                    child: TaqaFilledButton(
                      label: 'Apply',
                      height: 45,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Undoes an earlier decision so the suggestion goes back to the pending pile.
  Future<void> _resetItem(ProgressionReviewItem item) async {
    await _submitDecision(
      reviewItemId: item.reviewItemId,
      expertDecision: 'pending',
    );
  }

  Future<void> _editItem(ProgressionReviewItem item) async {
    final setsController = TextEditingController(
      text: (item.finalSets ?? item.aiRecommendedSets).toString(),
    );
    final repsController = TextEditingController(
      text: (item.finalReps ?? item.aiRecommendedReps).toString(),
    );
    // Leave the field blank when there is no weight to show. Pre-filling "0.0"
    // made an edit of sets alone silently write 0kg onto every set.
    final resolvedWeight = item.finalWeightKg ?? item.aiRecommendedWeightKg;
    final weightController = TextEditingController(
      text: resolvedWeight == null ? '' : resolvedWeight.toStringAsFixed(1),
    );
    final noteController = TextEditingController(text: item.expertNote ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: TaqaPopupDialog(
            bottomInset: bottomInset,
            onBackgroundTap: () =>
                FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Edit Recommendation',
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      color: TaqaUiColors.charcoal,
                    ),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _EditField(controller: setsController, label: 'Sets'),
                SizedBox(height: TaqaUiScale.h(12)),
                _EditField(controller: repsController, label: 'Reps'),
                SizedBox(height: TaqaUiScale.h(12)),
                _EditField(
                  controller: weightController,
                  label: 'Weight (kg)',
                  decimal: true,
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                _EditField(
                  controller: noteController,
                  label: 'Coach note',
                  numeric: false,
                ),
                SizedBox(height: TaqaUiScale.h(20)),
                SizedBox(
                  height: TaqaUiScale.h(45),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(false),
                          child: Center(
                            child: Text(
                              'CANCEL',
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
                      Expanded(
                        child: TaqaFilledButton(
                          label: 'Save',
                          height: 45,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          onTap: () => Navigator.of(ctx).pop(true),
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

    final weightText = weightController.text.trim();
    final setsText = setsController.text.trim();
    final repsText = repsController.text.trim();
    final noteText = noteController.text.trim();

    setsController.dispose();
    repsController.dispose();
    weightController.dispose();
    noteController.dispose();

    if (confirmed != true) return;

    await _submitDecision(
      reviewItemId: item.reviewItemId,
      expertDecision: 'edited',
      finalSets: int.tryParse(setsText),
      finalReps: int.tryParse(repsText),
      finalWeightKg: double.tryParse(weightText),
      // An emptied field means "no external load", not "leave it as it was".
      clearWeight: weightText.isEmpty,
      expertNote: noteText,
    );
  }

  Future<void> _submitDecision({
    required int reviewItemId,
    required String expertDecision,
    int? finalSets,
    int? finalReps,
    double? finalWeightKg,
    bool clearWeight = false,
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
        clearWeight: clearWeight,
        expertNote: expertNote,
      );
      if (!mounted) return;
      setState(() => _review = updated);
      AppToast.show(
        context,
        expertDecision == 'pending'
            ? 'Moved back to pending.'
            : 'Review item updated.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _review;
    final groupedDays = review == null
        ? const <_DayGroup>[]
        : _groupedDays(review);
    final canApply =
        review != null &&
        !review.isLocked &&
        review.items.any((item) => item.isApprovedLike);

    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.unnamedColor1c1d17,
        title: 'AI Updates',
      ),
      body: _loading
          ? const Center(child: TaqaLoadingIndicator())
          : review == null
          ? const Center(
              child: TaqaClientDashboardBodyText('Review unavailable.'),
            )
          : TaqaRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: TaqaUiScale.insetsLTRB(16, 12, 16, 24),
                children: [
                  _ReviewHeaderCard(review: review),
                  SizedBox(height: TaqaUiScale.h(20)),
                  for (final group in groupedDays) ...[
                    _DaySection(
                      group: group,
                      locked: review.isLocked,
                      busy: _saving,
                      onApprove: _approveItem,
                      onReject: _rejectItem,
                      onEdit: _editItem,
                      onReset: _resetItem,
                    ),
                    SizedBox(height: TaqaUiScale.h(20)),
                  ],
                  if (canApply)
                    TaqaFilledButton(
                      label: _saving ? 'Applying...' : 'Apply to Program',
                      loading: _saving,
                      height: 48,
                      fontSize: 11,
                      onTap: _saving ? null : _applyReview,
                    ),
                ],
              ),
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADER CARD
// -----------------------------------------------------------------------------
class _ReviewHeaderCard extends StatelessWidget {
  const _ReviewHeaderCard({required this.review});

  final ProgressionReviewDetail review;

  Color _statusColor() {
    switch (review.status) {
      case 'applied':
        return _successGreen;
      case 'failed':
        return TaqaUiColors.recordRed;
      case 'pending_expert':
        return TaqaUiColors.recordRed;
      case 'reviewed':
        return _successGreen;
      case 'cancelled':
        return TaqaUiColors.charcoal;
      default:
        return TaqaUiColors.charcoal;
    }
  }

  String _statusLabel() {
    switch (review.status) {
      case 'pending_expert':
        final pending = review.pendingItemCount;
        return pending > 0 ? 'PENDING - $pending LEFT' : 'PENDING';
      case 'reviewed':
        return 'READY TO APPLY';
      case 'applied':
        return 'APPLIED';
      case 'failed':
        return 'NEEDS RETRY';
      case 'pending_ai':
        return 'GENERATING';
      case 'cancelled':
        return 'EXPIRED - WEEK ENDED';
      default:
        return review.status.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TaqaClientDashboardCard(
      padding: 14,
      radius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TaqaClientDashboardTitleText(
                  review.clientName ?? 'Client #${review.userId}',
                ),
              ),
              SizedBox(width: TaqaUiScale.w(8)),
              TaqaClientDashboardStatusPill(
                label: _statusLabel(),
                color: _statusColor(),
              ),
            ],
          ),
          SizedBox(height: TaqaUiScale.h(2)),
          Text(
            'Week ${review.weekStart ?? '-'} to ${review.weekEnd ?? '-'}',
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(12),
              fontWeight: FontWeight.w400,
              height: 16 / 12,
              color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
            ),
          ),
          if ((review.aiSummary ?? '').trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaClientDashboardBodyText(review.aiSummary!),
          ],
          if ((review.lastError ?? '').trim().isNotEmpty) ...[
            SizedBox(height: TaqaUiScale.h(12)),
            TaqaClientDashboardBodyText(
              review.lastError!,
              color: TaqaUiColors.recordRed,
            ),
          ],
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DAY GROUPING
// -----------------------------------------------------------------------------
class _DayGroup {
  const _DayGroup({
    required this.key,
    required this.title,
    required this.items,
  });

  final String key;
  final String title;
  final List<ProgressionReviewItem> items;

  int get pendingCount => items.where((item) => item.isPending).length;
  int get doneCount => items.where((item) => item.isDone).length;
}

List<_DayGroup> _groupedDays(ProgressionReviewDetail review) {
  final grouped = <String, List<ProgressionReviewItem>>{};
  for (final item in review.items) {
    final dayIndex = item.dayIndex;
    final dayLabel = (item.dayLabel ?? '').trim();
    final key =
        '${dayIndex ?? 999}-${item.programDayId ?? 0}-${dayLabel.isEmpty ? 'day' : dayLabel}';
    grouped.putIfAbsent(key, () => <ProgressionReviewItem>[]).add(item);
  }

  final groups = grouped.entries.map((entry) {
    final first = entry.value.first;
    final index = first.dayIndex;
    final label = (first.dayLabel ?? '').trim();
    final title = index != null
        ? 'Day $index${label.isNotEmpty ? ' - $label' : ''}'
        : (label.isNotEmpty ? label : 'Training Day');
    return _DayGroup(key: entry.key, title: title, items: entry.value);
  }).toList();

  groups.sort((a, b) {
    final aIndex = a.items.first.dayIndex ?? 999;
    final bIndex = b.items.first.dayIndex ?? 999;
    if (aIndex != bIndex) return aIndex.compareTo(bIndex);
    return a.title.compareTo(b.title);
  });
  return groups;
}

// -----------------------------------------------------------------------------
// DAY SECTION (header + tags + exercise cards)
// -----------------------------------------------------------------------------
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.group,
    required this.locked,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onReset,
  });

  final _DayGroup group;
  final bool locked;
  final bool busy;
  final Future<void> Function(ProgressionReviewItem item) onApprove;
  final Future<void> Function(ProgressionReviewItem item) onReject;
  final Future<void> Function(ProgressionReviewItem item) onEdit;
  final Future<void> Function(ProgressionReviewItem item) onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaClientDashboardTitleText(group.title),
        SizedBox(height: TaqaUiScale.h(2)),
        Text(
          '${group.items.length} exercise(s)',
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w400,
            height: 12 / 10,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
          ),
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        Row(
          children: [
            _CountTag(
              label: '${group.pendingCount} Pending',
              borderColor: group.pendingCount > 0
                  ? TaqaUiColors.recordRed
                  : null,
            ),
            SizedBox(width: TaqaUiScale.w(6)),
            _CountTag(
              label: '${group.doneCount} Done',
              borderColor: group.doneCount > 0 ? _successGreen : null,
            ),
          ],
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        for (var i = 0; i < group.items.length; i++) ...[
          _ReviewItemCard(
            item: group.items[i],
            locked: locked,
            busy: busy,
            onApprove: () => onApprove(group.items[i]),
            onReject: () => onReject(group.items[i]),
            onEdit: () => onEdit(group.items[i]),
            onReset: () => onReset(group.items[i]),
          ),
          if (i < group.items.length - 1) SizedBox(height: TaqaUiScale.h(16)),
        ],
      ],
    );
  }
}

class _CountTag extends StatelessWidget {
  const _CountTag({required this.label, this.borderColor});

  final String label;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TaqaOutlineTagButton(
        label: label,
        width: double.infinity,
        borderColor: borderColor,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EXERCISE CARD + ACTION BUTTONS
// -----------------------------------------------------------------------------
class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.locked,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onReset,
  });

  final ProgressionReviewItem item;
  final bool locked;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  static String _sets(int? n) =>
      n == null ? '-' : '$n ${n == 1 ? 'set' : 'sets'}';
  static String _reps(int? n) =>
      n == null ? '-' : '$n ${n == 1 ? 'rep' : 'reps'}';
  static String _wt(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)}kg';

  String get _currentValue =>
      '${_sets(item.currentSets)}, ${_reps(item.currentReps)}, ${_wt(item.currentWeightKg)}';

  String get _observedValue {
    if (item.observedSets == null &&
        item.observedReps == null &&
        item.observedWeightKg == null) {
      return 'No data logged';
    }
    return '${_sets(item.observedSets)}, ${_reps(item.observedReps)}, '
        '${_wt(item.observedWeightKg)}, RIR ${item.observedRir ?? '-'}';
  }

  String get _aiValue =>
      '${item.aiAction.replaceAll('_', ' ')}, ${_sets(item.aiRecommendedSets)}, '
      '${_reps(item.aiRecommendedReps)}, ${_wt(item.aiRecommendedWeightKg)}';

  String get _finalValue {
    if (item.isRejected) return 'No change';
    final s = item.finalSets ?? item.aiRecommendedSets;
    final r = item.finalReps ?? item.aiRecommendedReps;
    final w = item.finalWeightKg ?? item.aiRecommendedWeightKg;
    return '${_sets(s)}, ${_reps(r)}, ${_wt(w)}';
  }

  /// Durable record of what the coach settled on, shown once it is on the plan.
  String? get _appliedCaption {
    if (item.appliedAt == null) return null;
    final stamp = item.appliedAt!.split('T').first;
    final values =
        '${_sets(item.appliedSets)}, ${_reps(item.appliedReps)}, '
        '${_wt(item.appliedWeightKg)}';
    return '${item.decisionLabel} - $values - applied $stamp';
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = item.isRejected;
    final done = item.isDone;
    final appliedCaption = _appliedCaption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaqaClientDashboardCard(
          padding: 14,
          radius: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TaqaClientDashboardTitleText(item.exerciseName),
                  ),
                  SizedBox(width: TaqaUiScale.w(8)),
                  TaqaClientDashboardStatusPill(
                    label: done ? 'DONE' : 'PENDING',
                    color: done ? _successGreen : TaqaUiColors.recordRed,
                  ),
                ],
              ),
              SizedBox(height: TaqaUiScale.h(10)),
              _MetricRow(label: 'Current', value: _currentValue),
              SizedBox(height: TaqaUiScale.h(4)),
              _MetricRow(label: 'Observed', value: _observedValue),
              SizedBox(height: TaqaUiScale.h(4)),
              _MetricRow(label: 'AI', value: _aiValue),
              SizedBox(height: TaqaUiScale.h(4)),
              _MetricRow(label: 'Final', value: _finalValue),
              if ((item.aiReason ?? '').trim().isNotEmpty) ...[
                SizedBox(height: TaqaUiScale.h(10)),
                TaqaClientDashboardBodyText(item.aiReason!),
              ],
              if ((item.expertNote ?? '').trim().isNotEmpty) ...[
                SizedBox(height: TaqaUiScale.h(8)),
                TaqaClientDashboardBodyText(
                  'Coach note: ${item.expertNote!}',
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
                ),
              ],
              SizedBox(height: TaqaUiScale.h(8)),
              TaqaClientDashboardBodyText(
                appliedCaption ?? item.decisionLabel,
                color: done
                    ? _successGreen
                    : TaqaUiColors.charcoal.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
        SizedBox(height: TaqaUiScale.h(10)),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: isRejected ? 'Rejected' : 'Reject',
                textColor: TaqaUiColors.recordRed,
                borderColor: TaqaUiColors.recordRed,
                fillColor: isRejected
                    ? TaqaUiColors.recordRed.withValues(alpha: 0.14)
                    : null,
                onTap: busy || locked || isRejected ? null : onReject,
              ),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              child: _ActionButton(
                label: item.isEdited ? 'Edited' : 'Edit',
                textColor: TaqaUiColors.charcoal,
                borderColor: item.isEdited
                    ? _successGreen
                    : TaqaUiColors.charcoal.withValues(alpha: 0.12),
                onTap: busy || locked ? null : onEdit,
              ),
            ),
            SizedBox(width: TaqaUiScale.w(10)),
            Expanded(
              // Once decided, this slot becomes the single undo affordance -- so
              // every done state (approved, edited, rejected) has one way back
              // to pending.
              child: done
                  ? _ActionButton(
                      label: 'Undo',
                      textColor: TaqaUiColors.charcoal,
                      borderColor: TaqaUiColors.charcoal.withValues(alpha: 0.35),
                      onTap: busy || locked ? null : onReset,
                    )
                  : _ActionButton(
                      label: 'Approve',
                      textColor: TaqaUiColors.charcoal,
                      fillColor: TaqaUiColors.lime,
                      onTap: busy || locked ? null : onApprove,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            fontWeight: FontWeight.w400,
            height: 18 / 15,
            letterSpacing: 0,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.62),
          ),
        ),
        SizedBox(width: TaqaUiScale.w(8)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(15),
              fontWeight: FontWeight.w400,
              height: 18 / 15,
              letterSpacing: 0,
              color: TaqaUiColors.charcoal,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.textColor,
    this.fillColor,
    this.borderColor,
    this.onTap,
  });

  final String label;
  final Color textColor;
  final Color? fillColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: fillColor ?? TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(5),
        child: InkWell(
          borderRadius: TaqaUiScale.radius(5),
          onTap: onTap,
          child: Container(
            height: TaqaUiScale.h(48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: TaqaUiScale.radius(5),
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor!),
            ),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: TaqaUiFontFamilies.interTight,
                fontSize: TaqaUiScale.sp(11),
                fontWeight: FontWeight.w700,
                height: 12 / 11,
                letterSpacing: 0,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    this.numeric = true,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final bool numeric;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(10),
            fontWeight: FontWeight.w400,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.6),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: numeric
              ? TextInputType.numberWithOptions(decimal: decimal)
              : TextInputType.text,
          cursorColor: TaqaUiColors.charcoal,
          style: TextStyle(
            fontFamily: TaqaUiFontFamilies.interTight,
            fontSize: TaqaUiScale.sp(15),
            height: 21 / 15,
            color: TaqaUiColors.charcoal,
          ),
          decoration: const InputDecoration(
            isDense: true,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: TaqaUiColors.charcoal, width: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}
