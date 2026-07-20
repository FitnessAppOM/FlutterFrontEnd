import 'package:flutter/material.dart';

import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/progression_review_service.dart';
import '../TaqaUI/Typography/taqa_ui_typography.dart';
import '../TaqaUI/components/taqa_outline_tag_button.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_refresh_indicator.dart';
import '../TaqaUI/components/taqa_toast.dart';
import '../TaqaUI/styles/taqa_ui_scale.dart';
import '../TaqaUI/styles/taqa_ui_styles.dart';
import '../TaqaUI/taqa_ui_colors.dart';

class ExpertConnectionRequestsPage extends StatefulWidget {
  const ExpertConnectionRequestsPage({super.key});

  @override
  State<ExpertConnectionRequestsPage> createState() =>
      _ExpertConnectionRequestsPageState();
}

class _ExpertConnectionRequestsPageState
    extends State<ExpertConnectionRequestsPage> {
  bool _loading = true;
  bool _sendingBulkMessageToRed = false;
  int _redStatusClientCount = 0;
  final Set<String> _actingRequestKeys = <String>{};
  CoachConnectionRequestSummary _summary = const CoachConnectionRequestSummary(
    items: <CoachConnectionRequestItem>[],
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ProgressionReviewService.fetchPendingConnectionRequests(),
        ProgressionReviewService.fetchClients(),
      ]);
      final summary = results[0] as CoachConnectionRequestSummary;
      final clients = results[1] as List<ProgressionClient>;
      final redCount = clients.where((client) {
        return (client.activityStatus ?? '').trim().toLowerCase() == 'red';
      }).length;
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _redStatusClientCount = redCount;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(
    CoachConnectionRequestItem request, {
    required bool accept,
  }) async {
    final key = request.stableKey;
    final clientUserId = request.clientUserId;
    if (_actingRequestKeys.contains(key)) return;
    setState(() {
      _actingRequestKeys.add(key);
    });
    try {
      await ProgressionReviewService.decideConnectionRequest(
        clientUserId: clientUserId,
        accept: accept,
      );
      if (!mounted) return;
      _removeRequestLocally(request);
      AppToast.show(
        context,
        accept ? 'Request accepted.' : 'Request denied.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _actingRequestKeys.remove(key);
        });
      }
    }
  }

  Future<void> _ackDetach(CoachConnectionRequestItem request) async {
    final key = request.stableKey;
    if (_actingRequestKeys.contains(key)) return;
    setState(() {
      _actingRequestKeys.add(key);
    });
    try {
      await ProgressionReviewService.acknowledgeDetachedClientEvent(
        clientUserId: request.clientUserId,
      );
      if (!mounted) return;
      _removeRequestLocally(request);
      AppToast.show(
        context,
        'Detach notification acknowledged.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _actingRequestKeys.remove(key);
        });
      }
    }
  }

  void _removeRequestLocally(CoachConnectionRequestItem request) {
    setState(() {
      final items = _summary.items
          .where((item) => item.stableKey != request.stableKey)
          .toList(growable: false);
      final newCount = items.where((item) => item.isNew).length;
      _summary = CoachConnectionRequestSummary(
        items: items,
        pendingCount: items.length,
        newPendingCount: newCount,
        hasNewRequests: newCount > 0,
      );
    });
  }

  Future<void> _sendBulkMessageToRedClients() async {
    if (_sendingBulkMessageToRed) return;
    if (_redStatusClientCount <= 0) {
      AppToast.show(
        context,
        'No red-status clients right now.',
        type: AppToastType.info,
      );
      return;
    }

    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bulk Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will send to $_redStatusClientCount red-status clients.',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Write your message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(ctx).pop(value);
              },
              child: const Text('Confirm Send'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    final message = (text ?? '').trim();
    if (message.isEmpty) return;

    setState(() => _sendingBulkMessageToRed = true);
    try {
      final result =
          await CoachSupportChatService.sendCoachBulkMessageToRedClients(
            text: message,
          );
      if (!mounted) return;
      final sentRaw = result['sent_count'] ?? result['sentCount'];
      final sentCount = int.tryParse(sentRaw?.toString() ?? '') ?? 0;
      if (sentCount <= 0) {
        AppToast.show(
          context,
          'No red-status clients available at send time.',
          type: AppToastType.info,
        );
      } else {
        AppToast.show(
          context,
          sentCount == 1 ? 'Sent to 1 client.' : 'Sent to $sentCount clients.',
          type: AppToastType.success,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _sendingBulkMessageToRed = false);
    }
  }

  String _formatDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Unknown date';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
      appBar: TaqaPageAppBar(
        backgroundColor: TaqaUiColors.unnamedColorE3e3e3,
        titleColor: TaqaUiColors.unnamedColor1c1d17,
        title: 'Inbox',
        trailing: Padding(
          padding: EdgeInsets.only(right: TaqaUiScale.w(9)),
          child: Center(
            child: TaqaOutlineTagButton(
              label: 'Bulk message',
              width: TaqaUiScale.w(85),
              height: TaqaUiScale.h(20),
              onTap: _sendingBulkMessageToRed
                  ? null
                  : _sendBulkMessageToRedClients,
              borderColor: TaqaUiColors.unnamedColorE93b3b,
              textStyle: TaqaUiStyles.streakTag.copyWith(
                color: TaqaUiColors.unnamedColorE93b3b,
              ),
              icon: _sendingBulkMessageToRed
                  ? SizedBox(
                      width: TaqaUiScale.w(8),
                      height: TaqaUiScale.h(8),
                      child: const CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: TaqaUiColors.unnamedColorE93b3b,
                      ),
                    )
                  : Icon(
                      Icons.campaign,
                      size: TaqaUiScale.w(8),
                      color: TaqaUiColors.unnamedColorE93b3b,
                    ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TaqaUiColors.lime),
            )
          : TaqaRefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: TaqaUiScale.insetsLTRB(16, 10, 16, 16),
                children: [
                  if (_summary.items.isEmpty)
                    Text(
                      'No pending requests.',
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(10),
                        fontWeight: FontWeight.w400,
                        height: 18 / 10,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17,
                      ),
                    )
                  else
                    ..._summary.items.map((request) {
                      final acting = _actingRequestKeys.contains(
                        request.stableKey,
                      );
                      final isDetachEvent = request.isDetachEvent;
                      return Container(
                        margin: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                        padding: TaqaUiScale.insetsLTRB(14, 10, 14, 15),
                        decoration: BoxDecoration(
                          color: TaqaUiColors.white,
                          borderRadius: TaqaUiScale.radius(15),
                          border: Border.all(
                            color: request.isNew
                                ? const Color(
                                    0xFF3BE971,
                                  ).withValues(alpha: 0.55)
                                : TaqaUiColors.unnamedColor1c1d17.withValues(
                                    alpha: 0.10,
                                  ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    request.clientName ??
                                        'Client #${request.clientUserId}',
                                    style: TextStyle(
                                      fontFamily: TaqaUiFontFamilies.interTight,
                                      color: TaqaUiColors.unnamedColor1c1d17,
                                      fontSize: TaqaUiScale.sp(15),
                                      fontWeight: FontWeight.w700,
                                      height: 18 / 15,
                                    ),
                                  ),
                                ),
                                if (request.isNew)
                                  TaqaOutlineTagButton(
                                    label: 'New',
                                    width: TaqaUiScale.w(38),
                                    height: TaqaUiScale.h(20),
                                    borderColor: const Color(0xFF3BE971),
                                    textStyle: TaqaUiStyles.streakTag.copyWith(
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: TaqaUiScale.h(4)),
                            Text(
                              request.clientEmail ??
                                  'user_id: ${request.clientUserId}',
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                color: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.70),
                                fontSize: TaqaUiScale.sp(12),
                              ),
                            ),
                            SizedBox(height: TaqaUiScale.h(4)),
                            Text(
                              isDetachEvent
                                  ? 'Detached: ${_formatDate(request.detachedAt ?? request.updatedAt)}'
                                  : 'Requested: ${_formatDate(request.requestedAt)}',
                              style: TextStyle(
                                fontFamily: TaqaUiFontFamilies.interTight,
                                color: TaqaUiColors.unnamedColor1c1d17
                                    .withValues(alpha: 0.54),
                                fontSize: TaqaUiScale.sp(12),
                              ),
                            ),
                            SizedBox(height: TaqaUiScale.h(12)),
                            if (isDetachEvent)
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: acting
                                      ? null
                                      : () => _ackDetach(request),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor:
                                        TaqaUiColors.unnamedColorE4e93b,
                                    foregroundColor:
                                        TaqaUiColors.unnamedColor1c1d17,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: TaqaUiScale.radius(5),
                                    ),
                                  ),
                                  child: acting
                                      ? SizedBox(
                                          width: TaqaUiScale.w(16),
                                          height: TaqaUiScale.h(16),
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: TaqaUiColors
                                                    .unnamedColor1c1d17,
                                              ),
                                        )
                                      : Text(
                                          'OK',
                                          style: TextStyle(
                                            fontFamily:
                                                TaqaUiFontFamilies.interTight,
                                            fontSize: TaqaUiScale.sp(10),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: acting
                                          ? null
                                          : () =>
                                                _decide(request, accept: false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            TaqaUiColors.unnamedColorE93b3b,
                                        side: const BorderSide(
                                          color:
                                              TaqaUiColors.unnamedColorE93b3b,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: TaqaUiScale.radius(5),
                                        ),
                                      ),
                                      child: Text(
                                        'DENY',
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          fontSize: TaqaUiScale.sp(10),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: TaqaUiScale.w(8)),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: acting
                                          ? null
                                          : () =>
                                                _decide(request, accept: true),
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor:
                                            TaqaUiColors.unnamedColorE4e93b,
                                        foregroundColor:
                                            TaqaUiColors.unnamedColor1c1d17,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: TaqaUiScale.radius(5),
                                        ),
                                      ),
                                      child: acting
                                          ? SizedBox(
                                              width: TaqaUiScale.w(16),
                                              height: TaqaUiScale.h(16),
                                              child:
                                                  const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: TaqaUiColors
                                                        .unnamedColor1c1d17,
                                                  ),
                                            )
                                          : Text(
                                              'ACCEPT',
                                              style: TextStyle(
                                                fontFamily: TaqaUiFontFamilies
                                                    .interTight,
                                                fontSize: TaqaUiScale.sp(10),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
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
            ),
    );
  }
}
