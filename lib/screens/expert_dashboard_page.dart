import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/coach/progression_review_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ProgressionReviewService.fetchClients(),
        ProgressionReviewService.fetchReviews(includeApplied: true),
      ]);
      if (!mounted) return;
      setState(() {
        _clients = results[0] as List<ProgressionClient>;
        _reviews = results[1] as List<ProgressionReview>;
      });
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

  Future<void> _switchToProgression() async {
    if (!mounted) return;
    setState(() => _tabIndex = _tabProgression);
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(
            title: 'My Clients',
            subtitle:
                'Your assigned clients. Manage progression from the Progression tab.',
          ),
          const SizedBox(height: 10),
          if (_clients.isEmpty)
            const _EmptyCard(text: 'No assigned clients yet.')
          else
            ..._clients.map((client) {
              final totalReviews = _reviews
                  .where((r) => r.userId == client.userId)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClientOverviewCard(
                  client: client,
                  reviewCount: totalReviews,
                  onOpenProgression: _switchToProgression,
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        _SectionTitle(
          title: 'Nutrition',
          subtitle:
              'Review client nutrition plans, notes, and schedule updates.',
        ),
        SizedBox(height: 12),
        _EmptyCard(text: 'Nutrition workspace coming soon.'),
      ],
    );
  }

  Widget _buildSettingsTab(AppLocalizations t) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(
          title: t.translate('settings'),
          subtitle: 'Coach-side preferences and tools.',
        ),
        const SizedBox(height: 12),
        const _EmptyCard(text: 'Coach settings workspace coming soon.'),
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

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: Text(_appBarTitle(t)),
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
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.white60)),
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
    required this.onOpenProgression,
  });

  final ProgressionClient client;
  final int reviewCount;
  final VoidCallback onOpenProgression;

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
          const SizedBox(height: 8),
          Text(
            'Progression reviews: $reviewCount',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onOpenProgression,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Open Progression'),
            ),
          ),
        ],
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
