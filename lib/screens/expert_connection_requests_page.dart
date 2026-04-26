import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

class ExpertConnectionRequestsPage extends StatefulWidget {
  const ExpertConnectionRequestsPage({super.key});

  @override
  State<ExpertConnectionRequestsPage> createState() =>
      _ExpertConnectionRequestsPageState();
}

class _ExpertConnectionRequestsPageState
    extends State<ExpertConnectionRequestsPage> {
  bool _loading = true;
  bool _loadingCoachPin = false;
  String? _coachPin;
  final Set<String> _actingRequestKeys = <String>{};
  CoachConnectionRequestSummary _summary = const CoachConnectionRequestSummary(
    items: <CoachConnectionRequestItem>[],
  );

  @override
  void initState() {
    super.initState();
    _load();
    _loadCoachPin();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary =
          await ProgressionReviewService.fetchPendingConnectionRequests();
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCoachPin() async {
    if (_loadingCoachPin) return;
    _loadingCoachPin = true;
    try {
      final coachPin = await ProgressionReviewService.fetchMyCoachCode();
      if (!mounted) return;
      setState(() {
        _coachPin = coachPin;
      });
    } catch (_) {
      // Keep page usable if coach code endpoint is unavailable.
    } finally {
      _loadingCoachPin = false;
    }
  }

  Future<void> _copyCoachPin() async {
    final pin = (_coachPin ?? '').trim();
    if (pin.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pin));
    if (!mounted) return;
    AppToast.show(context, 'Coach PIN copied', type: AppToastType.success);
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
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Inbox'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loadingCoachPin)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        'Loading coach PIN...',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  if (!_loadingCoachPin && (_coachPin ?? '').trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pin_outlined,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Coach PIN: ${_coachPin!.trim()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _copyCoachPin,
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
                      ),
                    ),
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
