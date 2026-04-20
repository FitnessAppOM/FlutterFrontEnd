import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/base_url.dart';
import '../core/account_storage.dart';
import '../services/auth/profile_service.dart';
import '../services/coach/coach_habits_service.dart';
import '../services/coach/form_check_service.dart';
import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import 'expert_client_analytics_page.dart';
import 'expert_client_habits_page.dart';

class ExpertClientDetailPage extends StatefulWidget {
  const ExpertClientDetailPage({
    super.key,
    required this.client,
    required this.reviews,
  });

  final ProgressionClient client;
  final List<ProgressionReview> reviews;

  @override
  State<ExpertClientDetailPage> createState() => _ExpertClientDetailPageState();
}

class _ExpertClientDetailPageState extends State<ExpertClientDetailPage> {
  bool _loading = true;
  int? _expertId;
  Map<String, dynamic>? _profile;
  List<CoachHabitItem> _habits = const [];
  List<FormCheckSubmission> _sharedFormChecks = const [];
  String? _profileError;
  String? _habitsError;
  String? _formChecksError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _profileError = null;
        _habitsError = null;
        _formChecksError = null;
      });
    }

    Map<String, dynamic>? profile;
    List<CoachHabitItem> habits = const [];
    List<FormCheckSubmission> sharedFormChecks = const [];
    int? expertId;
    String? profileError;
    String? habitsError;
    String? formChecksError;

    try {
      expertId = await AccountStorage.getUserId();
    } catch (_) {
      expertId = null;
    }

    try {
      profile = await ProfileApi.fetchProfile(widget.client.userId);
    } catch (e) {
      profileError = e.toString();
    }

    try {
      habits = await CoachHabitsService.fetchClientHabits(
        clientId: widget.client.userId,
        expertId: expertId,
        includeCompleted: true,
      );
    } catch (e) {
      habitsError = _normalizeHabitsError(e);
    }

    try {
      sharedFormChecks =
          await ProgressionReviewService.fetchClientSharedFormChecks(
            widget.client.userId,
          );
    } catch (e) {
      formChecksError = _normalizeHabitsError(e);
    }

    if (!mounted) return;
    setState(() {
      _expertId = expertId;
      _profile = profile;
      _habits = habits;
      _sharedFormChecks = sharedFormChecks;
      _profileError = profileError;
      _habitsError = habitsError;
      _formChecksError = formChecksError;
      _loading = false;
    });
  }

  String _normalizeHabitsError(Object error) {
    final raw = error.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('forbidden') || lower.contains('403')) {
      return 'Non available';
    }
    if (raw.startsWith('Exception: ')) {
      final clean = raw.substring('Exception: '.length).trim();
      if (clean.isNotEmpty) return clean;
    }
    return raw.isEmpty ? 'Non available' : raw;
  }

  String _displayName() {
    final fromClient = (widget.client.name ?? '').trim();
    if (fromClient.isNotEmpty) return fromClient;
    final fromProfile = ((_profile?['full_name'] ?? _profile?['name']) ?? '')
        .toString()
        .trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    return 'Client #${widget.client.userId}';
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String? _normalizeAvatarUrl(String? rawValue) {
    final raw = rawValue?.trim() ?? '';
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

  String? _resolvedAvatarUrl() {
    return _normalizeAvatarUrl(widget.client.avatarUrl) ??
        _normalizeAvatarUrl(_profile?['avatar_url']?.toString());
  }

  String _value(dynamic raw, {String fallback = '-'}) {
    final text = (raw ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }

  Color _activityColor() {
    switch ((widget.client.activityStatus ?? '').trim().toLowerCase()) {
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

  String _activityLabel() {
    final status = (widget.client.activityStatus ?? '').trim().toLowerCase();
    if (status == 'green') return 'Active';
    if (status == 'yellow') {
      if (widget.client.inactiveDays != null) {
        return 'Inactive ${widget.client.inactiveDays} days';
      }
      return 'Inactive 3+ days';
    }
    if (widget.client.inactiveDays != null) {
      return 'Inactive ${widget.client.inactiveDays} days';
    }
    return 'Inactive 7+ days';
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Future<void> _openHabitsPage() async {
    final name = _displayName();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientHabitsPage(
          clientId: widget.client.userId,
          clientName: name,
          avatarUrl: _resolvedAvatarUrl(),
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAnalyticsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpertClientAnalyticsPage(
          client: widget.client,
          reviews: widget.reviews,
        ),
      ),
    );
  }

  Widget _buildClientOverviewCard() {
    final name = _displayName();
    final avatarUrl = (_resolvedAvatarUrl() ?? '').trim();
    final profile = _profile;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white10,
                foregroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'User ID: ${widget.client.userId}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _activityColor().withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _activityColor()),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _activityColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _activityLabel(),
                      style: TextStyle(
                        color: _activityColor(),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (_profileError != null)
            Text(
              _profileError!,
              style: const TextStyle(color: Colors.orangeAccent),
            )
          else if (profile == null)
            const Text(
              'No profile data available.',
              style: TextStyle(color: Colors.white70),
            )
          else
            Column(
              children: [
                _InfoRow(label: 'Age', value: _value(profile['age'])),
                const SizedBox(height: 6),
                _InfoRow(label: 'Sex', value: _value(profile['sex'])),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Height',
                  value: '${_value(profile['height_cm'])} cm',
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Weight',
                  value: '${_value(profile['weight_kg'])} kg',
                ),
                const SizedBox(height: 6),
                _InfoRow(label: 'Goal', value: _value(profile['fitness_goal'])),
                const SizedBox(height: 6),
                _InfoRow(
                  label: 'Training days',
                  value: _value(profile['training_days']),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAnalyticsPage,
        child: Ink(
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
                children: const [
                  Expanded(
                    child: Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Open client analytics and activity status.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _openAnalyticsPage,
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
                  icon: const Icon(Icons.insights_outlined, size: 16),
                  label: const Text('View Analytics'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitsCard() {
    final totalHabits = _habits.length;
    final checkedCount = _habits.where((habit) => habit.isCompleted).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _expertId == null ? null : _openHabitsPage,
        child: Ink(
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
                children: const [
                  Expanded(
                    child: Text(
                      'Habits',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              if (_habitsError != null)
                Text(
                  _habitsError!,
                  style: const TextStyle(color: Colors.white70),
                )
              else if (totalHabits == 0)
                const Text(
                  'No habits set yet.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                Column(
                  children: [
                    _InfoRow(label: 'Total habits', value: '$totalHabits'),
                    const SizedBox(height: 6),
                    _InfoRow(
                      label: 'Checked this week',
                      value: '$checkedCount',
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _expertId == null ? null : _openHabitsPage,
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
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Habits'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormReviewCard() {
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
            'Form Review',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Only videos explicitly shared by this client are shown.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          if (_formChecksError != null)
            Text(
              _formChecksError!,
              style: const TextStyle(color: Colors.white70),
            )
          else if (_sharedFormChecks.isEmpty)
            const Text(
              'No videos available for review.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._sharedFormChecks.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
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
                        item.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shared: ${_formatDateTime(item.sharedAt ?? item.createdAt)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openUrl(item.originalVideoUrl),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Open video'),
                          ),
                          if ((item.result.overlayUrl ?? '').trim().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _openUrl(item.result.overlayUrl),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                minimumSize: const Size(0, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                              ),
                              icon: const Icon(
                                Icons.insights_outlined,
                                size: 16,
                              ),
                              label: const Text('Open overlay'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildClientOverviewCard(),
        const SizedBox(height: 12),
        _buildAnalyticsCard(),
        const SizedBox(height: 12),
        _buildHabitsCard(),
        const SizedBox(height: 12),
        _buildFormReviewCard(),
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Client View'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(onRefresh: _load, child: list),
          if (_loading)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
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
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
