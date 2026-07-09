import 'package:flutter/material.dart';

import '../services/coach/coach_support_chat_service.dart';
import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../TaqaUI/components/taqa_page_app_bar.dart';
import '../TaqaUI/components/taqa_toast.dart';

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
      backgroundColor: AppColors.black,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.black,
        titleColor: Colors.white,
        title: 'Inbox',
        trailing: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Material(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _sendingBulkMessageToRed
                    ? null
                    : _sendBulkMessageToRedClients,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_sendingBulkMessageToRed)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      else
                        const Icon(
                          Icons.campaign_outlined,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'Bulk Message',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (_redStatusClientCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _redStatusClientCount > 99
                                ? '99+'
                                : '$_redStatusClientCount',
                            style: const TextStyle(
                              color: Colors.redAccent,
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        'No pending requests.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    ..._summary.items.map((request) {
                      final acting = _actingRequestKeys.contains(
                        request.stableKey,
                      );
                      final isDetachEvent = request.isDetachEvent;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: request.isNew
                                ? const Color(
                                    0xFF4ADE80,
                                  ).withValues(alpha: 0.55)
                                : Colors.white10,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (request.isNew)
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
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Color(0xFFA7F3D0),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              request.clientEmail ??
                                  'user_id: ${request.clientUserId}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDetachEvent
                                  ? 'Detached: ${_formatDate(request.detachedAt ?? request.updatedAt)}'
                                  : 'Requested: ${_formatDate(request.requestedAt)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (isDetachEvent)
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: acting
                                      ? null
                                      : () => _ackDetach(request),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: acting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('OK'),
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
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      child: const Text('Deny'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: acting
                                          ? null
                                          : () =>
                                                _decide(request, accept: true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF16A34A,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: acting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Accept'),
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
