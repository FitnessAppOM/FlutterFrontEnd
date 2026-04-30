import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/account_storage.dart';
import '../../services/community/community_models.dart';
import '../../services/community/community_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Main/card_container.dart';
import '../../widgets/Main/section_header.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/confirm_dialog.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  CommunityBootstrap? _bootstrap;
  List<CommunityFeedItem> _feed = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _selectedGroupId;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bootstrap = await CommunityService.fetchBootstrap();
      final feedPage = await CommunityService.fetchFeed(groupId: _selectedGroupId);
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _feed = feedPage.items;
        _nextCursor = feedPage.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refreshFeed() async {
    try {
      final bootstrap = await CommunityService.fetchBootstrap();
      final feedPage = await CommunityService.fetchFeed(groupId: _selectedGroupId);
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _feed = feedPage.items;
        _nextCursor = feedPage.nextCursor;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CommunityService.fetchFeed(
        groupId: _selectedGroupId,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _feed = [..._feed, ...page.items];
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _toggleLike(CommunityFeedItem item) async {
    final updated = item.currentUserLiked
        ? item.copyWith(
            currentUserLiked: false,
            likeCount: item.likeCount > 0 ? item.likeCount - 1 : 0,
          )
        : item.copyWith(
            currentUserLiked: true,
            likeCount: item.likeCount + 1,
          );
    setState(() {
      _feed = _feed
          .map((feedItem) => feedItem.feedItemId == item.feedItemId ? updated : feedItem)
          .toList(growable: false);
    });
    try {
      if (item.currentUserLiked) {
        await CommunityService.unlikeFeedItem(item.feedItemId);
      } else {
        await CommunityService.likeFeedItem(item.feedItemId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feed = _feed
            .map((feedItem) => feedItem.feedItemId == item.feedItemId ? item : feedItem)
            .toList(growable: false);
      });
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openComments(CommunityFeedItem item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(feedItem: item),
    );
    if (changed == true) {
      await _refreshFeed();
    }
  }

  bool _isAdminForGroup(int groupId) {
    return _bootstrap?.joinedGroups.any((group) => group.id == groupId && group.isAdmin) == true;
  }

  Future<void> _showReportSheet({
    required String targetType,
    required int targetId,
  }) async {
    final result = await _showReportDialog(context);
    if (result == null) return;
    try {
      await CommunityService.createReport(
        targetType: targetType,
        targetId: targetId,
        reason: result['reason'] as String,
        details: result['details'] as String?,
      );
      if (!mounted) return;
      AppToast.show(context, 'Report submitted.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _hideFeedItem(CommunityFeedItem item) async {
    try {
      await CommunityService.setFeedItemVisibility(
        item.feedItemId,
        isHidden: true,
      );
      if (!mounted) return;
      setState(() {
        _feed = _feed.where((entry) => entry.feedItemId != item.feedItemId).toList(growable: false);
      });
      AppToast.show(context, 'Feed item hidden.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _createGroup() async {
    final payload = await _showCreateGroupDialog(context);
    if (payload == null) return;
    try {
      final result = await CommunityService.createGroup(
        name: payload.name,
        visibility: payload.visibility,
        description: payload.description,
        groupKind: payload.groupKind,
        isDiscoverable: payload.isDiscoverable,
      );
      if (!mounted) return;
      AppToast.show(context, 'Group created.', type: AppToastType.success);
      if (payload.visibility == 'private' && result.joinCode != null) {
        await _showGroupCodeDialog(
          context,
          title: 'Private group code',
          code: result.joinCode!,
          message: 'Share this 6-digit code with anyone you want to invite.',
        );
        if (!mounted) return;
      }
      await _loadInitial();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityGroupDetailPage(groupId: result.group.id),
        ),
      );
      await _refreshFeed();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _joinByCode() async {
    final code = await _showJoinCodeDialog(context);
    if (code == null) return;
    try {
      final group = await CommunityService.joinGroupByCode(code);
      if (!mounted) return;
      AppToast.show(context, 'Joined ${group.name}.', type: AppToastType.success);
      await _loadInitial();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityGroupDetailPage(groupId: group.id),
        ),
      );
      await _refreshFeed();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openDiscover() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityDiscoverPage()),
    );
    await _refreshFeed();
  }

  Future<void> _openChallenges() async {
    final canAdminManage = _bootstrap?.hasAdminAccess ?? false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChallengesPage(canAdminManage: canAdminManage),
      ),
    );
    await _refreshFeed();
  }

  Future<void> _openBadges() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityBadgesPage()),
    );
    await _refreshFeed();
  }

  Future<void> _openAdminReports() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityAdminReportsPage()),
    );
    await _refreshFeed();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _refreshFeed,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const SectionHeader(title: 'Community'),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 18),
            _buildQuickActions(),
            const SizedBox(height: 18),
            if (_bootstrap != null) ...[
              _buildJoinedGroupsSection(),
              const SizedBox(height: 18),
              _buildChallengePreview(),
              const SizedBox(height: 18),
            ],
            _buildFeedFilterBar(),
            const SizedBox(height: 14),
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Community unavailable',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: _loadInitial,
              )
            else if (_feed.isEmpty)
              const _CommunityEmptyCard(
                title: 'Your feed is quiet',
                message: 'Join groups, share your data, and your real activity will start populating the feed.',
              )
            else
              ..._feed.map(_buildFeedCard),
            if (_nextCursor != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loadingMore
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load more'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final bootstrap = _bootstrap;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10274B),
            const Color(0xFF07111E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                backgroundImage: bootstrap?.currentUser.avatarUrl != null
                    ? NetworkImage(bootstrap!.currentUser.avatarUrl!)
                    : null,
                child: bootstrap?.currentUser.avatarUrl == null
                    ? const Icon(Icons.people_alt_outlined, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-generated community',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bootstrap == null
                          ? 'Loading your groups and activity'
                          : 'Welcome back, ${bootstrap.currentUser.primaryLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                label: 'Joined groups',
                value: '${bootstrap?.joinedGroups.length ?? 0}',
              ),
              _HeroMetric(
                label: 'Active challenges',
                value: '${bootstrap?.activeChallenges.length ?? 0}',
              ),
              _HeroMetric(
                label: 'Open reports',
                value: '${bootstrap?.unreadModerationReportNoticesCount ?? 0}',
                accent: (bootstrap?.unreadModerationReportNoticesCount ?? 0) > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final canAdminManage = _bootstrap?.hasAdminAccess ?? false;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionPill(
          label: 'Discover',
          icon: Icons.travel_explore_outlined,
          onTap: _openDiscover,
        ),
        _ActionPill(
          label: 'Join by Code',
          icon: Icons.password_outlined,
          onTap: _joinByCode,
        ),
        _ActionPill(
          label: 'Create Group',
          icon: Icons.add_circle_outline,
          onTap: _createGroup,
        ),
        _ActionPill(
          label: 'Challenges',
          icon: Icons.emoji_events_outlined,
          onTap: _openChallenges,
        ),
        _ActionPill(
          label: 'Badges',
          icon: Icons.workspace_premium_outlined,
          onTap: _openBadges,
        ),
        if ((_bootstrap?.unreadModerationReportNoticesCount ?? 0) > 0 || canAdminManage)
          _ActionPill(
            label: 'Reports',
            icon: Icons.flag_outlined,
            onTap: _openAdminReports,
            accent: true,
          ),
      ],
    );
  }

  Widget _buildJoinedGroupsSection() {
    final groups = _bootstrap?.joinedGroups ?? const <CommunityGroupSummary>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineSectionHeader(
          title: 'Your groups',
          actionLabel: 'Discover',
          onTap: _openDiscover,
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const _CommunityEmptyCard(
            title: 'No groups yet',
            message: 'Create a private group or discover a public community.',
          )
        else
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunityGroupDetailPage(groupId: group.id),
                      ),
                    );
                    await _refreshFeed();
                  },
                  child: SizedBox(
                    width: 220,
                    child: CardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _GroupBadge(group: group),
                              const Spacer(),
                              if (group.isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            group.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            group.description ?? 'No description yet.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${group.memberCount} members',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildChallengePreview() {
    final challenges = _bootstrap?.activeChallenges ?? const <CommunityChallenge>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineSectionHeader(
          title: 'Active challenges',
          actionLabel: 'Open all',
          onTap: _openChallenges,
        ),
        const SizedBox(height: 12),
        if (challenges.isEmpty)
          const _CommunityEmptyCard(
            title: 'No active challenges',
            message: 'Global community challenges will appear here when launched.',
          )
        else
          ...challenges.take(3).map(
            (challenge) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ChallengeCard(
                challenge: challenge,
                onTap: _openChallenges,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeedFilterBar() {
    final groups = _bootstrap?.joinedGroups ?? const <CommunityGroupSummary>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FeedFilterChip(
                label: 'All groups',
                selected: _selectedGroupId == null,
                onTap: () async {
                  setState(() => _selectedGroupId = null);
                  await _refreshFeed();
                },
              ),
              const SizedBox(width: 8),
              ...groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FeedFilterChip(
                    label: group.name,
                    selected: _selectedGroupId == group.id,
                    onTap: () async {
                      setState(() => _selectedGroupId = group.id);
                      await _refreshFeed();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedCard(CommunityFeedItem item) {
    final isAdmin = _isAdminForGroup(item.group.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(url: item.actor.avatarUrl, label: item.actor.primaryLabel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.actor.primaryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniChip(label: item.group.name),
                          _MiniChip(label: item.event.type.replaceAll('_', ' ')),
                          if (item.event.occurredAt != null)
                            _MiniChip(label: _formatDate(item.event.occurredAt)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.white70),
                  color: const Color(0xFF151515),
                  onSelected: (value) async {
                    if (value == 'report') {
                      await _showReportSheet(
                        targetType: 'feed_item',
                        targetId: item.feedItemId,
                      );
                    } else if (value == 'hide') {
                      await _hideFeedItem(item);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('Report'),
                    ),
                    if (isAdmin)
                      const PopupMenuItem<String>(
                        value: 'hide',
                        child: Text('Hide from group'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.event.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if ((item.event.subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.event.subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (item.event.payload.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildPayloadChips(item.event.payload),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _FeedActionButton(
                  icon: item.currentUserLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${item.likeCount}',
                  accent: item.currentUserLiked,
                  onTap: () => _toggleLike(item),
                ),
                const SizedBox(width: 10),
                _FeedActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${item.commentCount}',
                  enabled: item.canComment,
                  onTap: item.canComment ? () => _openComments(item) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPayloadChips(Map<String, dynamic> payload) {
    final entries = <Widget>[];
    const preferredKeys = [
      'score_current',
      'score_delta',
      'steps',
      'goal_steps',
      'streak_days',
      'workout_streak_days',
      'recovery_streak_days',
      'challenge_name',
      'milestone_percent',
      'badge_name',
      'habit_streak_weeks',
    ];
    for (final key in preferredKeys) {
      if (!payload.containsKey(key)) continue;
      final value = payload[key];
      if (value == null) continue;
      entries.add(
        _PayloadChip(
          label: key.replaceAll('_', ' '),
          value: value.toString(),
        ),
      );
    }
    return entries;
  }
}

class CommunityDiscoverPage extends StatefulWidget {
  const CommunityDiscoverPage({super.key});

  @override
  State<CommunityDiscoverPage> createState() => _CommunityDiscoverPageState();
}

class _CommunityDiscoverPageState extends State<CommunityDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<CommunityGroupSummary> _groups = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _groupKind;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await CommunityService.discoverGroups(
        query: _searchController.text.trim(),
        groupKind: _groupKind,
      );
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _nextCursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await CommunityService.discoverGroups(
        query: _searchController.text.trim(),
        groupKind: _groupKind,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        _groups.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openGroup(CommunityGroupSummary group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityGroupDetailPage(groupId: group.id),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('Discover Communities'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or description',
                suffixIcon: IconButton(
                  onPressed: () => _load(),
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeedFilterChip(
                  label: 'All kinds',
                  selected: _groupKind == null,
                  onTap: () async {
                    setState(() => _groupKind = null);
                    await _load();
                  },
                ),
                ...['general', 'gym', 'coach', 'city', 'country', 'sport'].map(
                  (kind) => _FeedFilterChip(
                    label: kind,
                    selected: _groupKind == kind,
                    onTap: () async {
                      setState(() => _groupKind = kind);
                      await _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load public groups',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (_groups.isEmpty)
              const _CommunityEmptyCard(
                title: 'No public groups found',
                message: 'Try a broader search or create your own private community.',
              )
            else
              ..._groups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _openGroup(group),
                    child: CardContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _GroupBadge(group: group),
                              const Spacer(),
                              if (group.isJoined)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Joined',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            group.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            group.description ?? 'No description available.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${group.memberCount} members',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_nextCursor != null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading...' : 'Load more'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CommunityGroupDetailPage extends StatefulWidget {
  const CommunityGroupDetailPage({
    super.key,
    required this.groupId,
  });

  final int groupId;

  @override
  State<CommunityGroupDetailPage> createState() => _CommunityGroupDetailPageState();
}

class _CommunityGroupDetailPageState extends State<CommunityGroupDetailPage> {
  CommunityGroupDetail? _detail;
  List<CommunityFeedItem> _feed = const [];
  List<CommunityMembership> _members = const [];
  bool _loading = true;
  String? _error;
  bool _groupNotificationsMuted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await CommunityService.fetchGroupDetail(widget.groupId);
      final feed = await CommunityService.fetchFeed(groupId: widget.groupId);
      final members = detail.isJoined
          ? await CommunityService.fetchGroupMembers(widget.groupId)
          : const <CommunityMembership>[];
      final currentUserId = await AccountStorage.getUserId();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _feed = feed.items;
        _members = members;
        _loading = false;
        _groupNotificationsMuted = members.any(
          (member) =>
              currentUserId != null &&
              member.userId == currentUserId &&
              member.mutedNotifications,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleShareSetting({
    required CommunityShareSettings Function(CommunityShareSettings settings) nextSettings,
  }) async {
    final detail = _detail;
    final current = detail?.shareSettings;
    if (detail == null || current == null) return;
    final optimistic = nextSettings(current);
    setState(() {
      _detail = CommunityGroupDetail(
        id: detail.id,
        name: detail.name,
        slug: detail.slug,
        description: detail.description,
        iconUrl: detail.iconUrl,
        visibility: detail.visibility,
        groupKind: detail.groupKind,
        adminUserId: detail.adminUserId,
        leaderboardMetric: detail.leaderboardMetric,
        isDiscoverable: detail.isDiscoverable,
        isReadOnly: detail.isReadOnly,
        memberCount: detail.memberCount,
        currentMemberRole: detail.currentMemberRole,
        isJoined: detail.isJoined,
        shareSettings: optimistic,
        pinnedItems: detail.pinnedItems,
        leaderboardSummary: detail.leaderboardSummary,
        createdAt: detail.createdAt,
        updatedAt: detail.updatedAt,
      );
    });
    try {
      final updated = await CommunityService.updateShareSettings(widget.groupId, optimistic);
      if (!mounted) return;
      setState(() {
        final active = _detail!;
        _detail = CommunityGroupDetail(
          id: active.id,
          name: active.name,
          slug: active.slug,
          description: active.description,
          iconUrl: active.iconUrl,
          visibility: active.visibility,
          groupKind: active.groupKind,
          adminUserId: active.adminUserId,
          leaderboardMetric: active.leaderboardMetric,
          isDiscoverable: active.isDiscoverable,
          isReadOnly: active.isReadOnly,
          memberCount: active.memberCount,
          currentMemberRole: active.currentMemberRole,
          isJoined: active.isJoined,
          shareSettings: updated,
          pinnedItems: active.pinnedItems,
          leaderboardSummary: active.leaderboardSummary,
          createdAt: active.createdAt,
          updatedAt: active.updatedAt,
        );
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
      await _load();
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Leave group',
      message: 'You can rejoin later if the group is public or if you still have the private code.',
      confirmText: 'Leave',
      borderColor: Colors.redAccent,
    );
    if (confirm != true) return;
    try {
      await CommunityService.leaveGroup(widget.groupId);
      if (!mounted) return;
      AppToast.show(context, 'Group left.', type: AppToastType.success);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _joinPrivateGroup() async {
    final code = await _showJoinCodeDialog(context);
    if (code == null) return;
    try {
      await CommunityService.joinGroupByCode(code);
      if (!mounted) return;
      AppToast.show(context, 'Joined group.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _joinPublicGroup() async {
    try {
      final group = await CommunityService.joinPublicGroup(widget.groupId);
      if (!mounted) return;
      AppToast.show(context, 'Joined ${group.name}.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _editGroup() async {
    final detail = _detail;
    if (detail == null) return;
    final payload = await _showEditGroupDialog(context, detail);
    if (payload == null) return;
    try {
      await CommunityService.updateGroup(
        widget.groupId,
        name: payload.name,
        description: payload.description,
        visibility: payload.visibility,
        groupKind: payload.groupKind,
        isDiscoverable: payload.isDiscoverable,
      );
      if (!mounted) return;
      AppToast.show(context, 'Group updated.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _resetCode() async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Reset join code',
      message: 'Anyone using the old 6-digit code will lose access to join.',
      confirmText: 'Reset',
    );
    if (confirm != true) return;
    try {
      final newCode = await CommunityService.regenerateJoinCode(widget.groupId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardDark,
          title: const Text('New group code', style: TextStyle(color: Colors.white)),
          content: Text(
            newCode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _viewCode() async {
    try {
      final code = await CommunityService.fetchGroupJoinCode(widget.groupId);
      if (!mounted) return;
      await _showGroupCodeDialog(
        context,
        title: 'Current group code',
        code: code,
        message: 'Share this 6-digit code with anyone you want to invite.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _changeLeaderboardMetric() async {
    final detail = _detail;
    if (detail == null) return;
    final metric = await _showMetricPicker(context, detail.leaderboardMetric ?? 'workout_streak');
    if (metric == null) return;
    try {
      await CommunityService.updateLeaderboardMetric(widget.groupId, metric);
      if (!mounted) return;
      AppToast.show(context, 'Leaderboard metric updated.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _createOrEditPin([CommunityPin? existing]) async {
    final result = await _showPinEditor(context, existing);
    if (result == null) return;
    try {
      if (existing == null) {
        await CommunityService.createPin(
          widget.groupId,
          pinType: result.pinType,
          title: result.title,
          body: result.body,
          sortOrder: result.sortOrder,
        );
      } else {
        await CommunityService.updatePin(
          widget.groupId,
          existing.pinId,
          title: result.title,
          body: result.body,
          sortOrder: result.sortOrder,
        );
      }
      if (!mounted) return;
      AppToast.show(
        context,
        existing == null ? 'Pin created.' : 'Pin updated.',
        type: AppToastType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _deletePin(CommunityPin pin) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Delete pin',
      message: 'This will remove the pinned item from the group.',
      confirmText: 'Delete',
      borderColor: Colors.redAccent,
    );
    if (confirm != true) return;
    try {
      await CommunityService.deletePin(widget.groupId, pin.pinId);
      if (!mounted) return;
      AppToast.show(context, 'Pin deleted.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openMembers() async {
    final detail = _detail;
    if (detail == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupMembersSheet(
        groupId: detail.id,
        groupName: detail.name,
        canAdminManage: detail.isAdmin,
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      await CommunityService.updateGroupNotifications(
        widget.groupId,
        mutedNotifications: value,
      );
      if (!mounted) return;
      setState(() => _groupNotificationsMuted = value);
      AppToast.show(context, 'Notification preference saved.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: Text(detail?.name ?? 'Community'),
        actions: [
          if (detail?.isAdmin == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.settings_outlined),
              color: const Color(0xFF141414),
              onSelected: (value) async {
                if (value == 'edit') {
                  await _editGroup();
                } else if (value == 'view_code') {
                  await _viewCode();
                } else if (value == 'code') {
                  await _resetCode();
                } else if (value == 'members') {
                  await _openMembers();
                } else if (value == 'metric') {
                  await _changeLeaderboardMetric();
                } else if (value == 'pin') {
                  await _createOrEditPin();
                } else if (value == 'reports') {
                  await _openGroupReports();
                } else if (value == 'archive') {
                  await _archiveGroup();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit group')),
                PopupMenuItem(value: 'view_code', child: Text('View join code')),
                PopupMenuItem(value: 'code', child: Text('Reset join code')),
                PopupMenuItem(value: 'members', child: Text('Manage members')),
                PopupMenuItem(value: 'reports', child: Text('Reports')),
                PopupMenuItem(value: 'metric', child: Text('Leaderboard metric')),
                PopupMenuItem(value: 'pin', child: Text('Add pin')),
                PopupMenuItem(value: 'archive', child: Text('Archive group')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load group',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (detail != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: detail.isPrivate
                        ? [const Color(0xFF3B1B4A), const Color(0xFF15111C)]
                        : [const Color(0xFF133A33), const Color(0xFF0D1715)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _GroupBadge(
                          group: CommunityGroupSummary(
                            id: detail.id,
                            name: detail.name,
                            memberCount: detail.memberCount,
                            isJoined: detail.isJoined,
                            isDiscoverable: detail.isDiscoverable,
                            isReadOnly: detail.isReadOnly,
                            visibility: detail.visibility,
                            groupKind: detail.groupKind,
                            currentMemberRole: detail.currentMemberRole,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            detail.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      detail.description ?? 'No description available.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _HeroMetric(label: 'Members', value: '${detail.memberCount}'),
                        _HeroMetric(label: 'Leaderboard', value: detail.leaderboardMetric ?? '-'),
                        if (detail.currentMemberRole != null)
                          _HeroMetric(label: 'Role', value: detail.currentMemberRole!),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: detail.isJoined ? _openMembers : null,
                            icon: const Icon(Icons.groups_2_outlined),
                            label: const Text('Members'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: detail.isJoined
                                ? _leaveGroup
                                : (detail.isPrivate ? _joinPrivateGroup : _joinPublicGroup),
                            icon: Icon(
                              detail.isJoined
                                  ? Icons.exit_to_app
                                  : (detail.isPrivate ? Icons.lock_open_outlined : Icons.group_add_outlined),
                            ),
                            label: Text(
                              detail.isJoined
                                  ? 'Leave group'
                                  : (detail.isPrivate ? 'Join by code' : 'Join group'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CardContainer(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.accent,
                      title: const Text(
                        'Mute notifications',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Stay in the group without community alerts.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
                      ),
                      value: _groupNotificationsMuted,
                      onChanged: detail.isJoined ? _toggleNotifications : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (detail.shareSettings != null)
                CardContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shared metrics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose exactly what this group can see from your real activity.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
                      ),
                      const SizedBox(height: 12),
                      _ShareToggleTile(
                        title: 'Training progress',
                        value: detail.shareSettings!.shareTrainingProgress,
                        onChanged: (value) => _toggleShareSetting(
                          nextSettings: (settings) => settings.copyWith(shareTrainingProgress: value),
                        ),
                      ),
                      _ShareToggleTile(
                        title: 'TAQA score',
                        value: detail.shareSettings!.shareTaqaScore,
                        onChanged: (value) => _toggleShareSetting(
                          nextSettings: (settings) => settings.copyWith(shareTaqaScore: value),
                        ),
                      ),
                      _ShareToggleTile(
                        title: 'Daily movement',
                        value: detail.shareSettings!.shareDailyMovement,
                        onChanged: (value) => _toggleShareSetting(
                          nextSettings: (settings) => settings.copyWith(shareDailyMovement: value),
                        ),
                      ),
                      _ShareToggleTile(
                        title: 'Wearable data',
                        value: detail.shareSettings!.shareWearableData,
                        onChanged: (value) => _toggleShareSetting(
                          nextSettings: (settings) => settings.copyWith(shareWearableData: value),
                        ),
                      ),
                      _ShareToggleTile(
                        title: 'Wellness',
                        value: detail.shareSettings!.shareWellness,
                        onChanged: (value) => _toggleShareSetting(
                          nextSettings: (settings) => settings.copyWith(shareWellness: value),
                        ),
                      ),
                    ],
                  ),
                ),
              if (detail.shareSettings != null) const SizedBox(height: 16),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pinned items',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (detail.isAdmin)
                          TextButton(
                            onPressed: () => _createOrEditPin(),
                            child: const Text('Add'),
                          ),
                      ],
                    ),
                    if (detail.pinnedItems.isEmpty)
                      const Text(
                        'No pins yet.',
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      ...detail.pinnedItems.map(
                        (pin) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _MiniChip(label: pin.pinType.replaceAll('_', ' ')),
                                    const Spacer(),
                                    if (detail.isAdmin)
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_horiz, color: Colors.white70),
                                        color: const Color(0xFF141414),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _createOrEditPin(pin);
                                          } else if (value == 'delete') {
                                            await _deletePin(pin);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  pin.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  pin.body,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.74),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CardContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Leaderboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (detail.isAdmin)
                          TextButton(
                            onPressed: _changeLeaderboardMetric,
                            child: const Text('Change metric'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Metric: ${detail.leaderboardSummary.metric}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 12),
                    if (detail.leaderboardSummary.items.isEmpty)
                      const Text(
                        'No leaderboard data yet.',
                        style: TextStyle(color: Colors.white70),
                      )
                    else
                      ...detail.leaderboardSummary.items.take(5).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '#${entry.rankPosition}',
                                  style: TextStyle(
                                    color: entry.isCurrentUser ? AppColors.accent : Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.displayName,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                entry.scoreLabel,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InlineSectionHeader(
                title: 'Group feed',
                actionLabel: detail.isAdmin ? 'Members' : null,
                onTap: detail.isAdmin ? _openMembers : null,
              ),
              const SizedBox(height: 12),
              if (_feed.isEmpty)
                const _CommunityEmptyCard(
                  title: 'No activity yet',
                  message: 'This group feed will populate from real workouts, badges, score improvements, movement, and challenges.',
                )
              else
                ..._feed.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupFeedCard(
                      item: item,
                      canAdminManage: detail.isAdmin,
                      onCommentsTap: item.canComment
                          ? () async {
                              final changed = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _CommentsSheet(feedItem: item),
                              );
                              if (changed == true) {
                                await _load();
                              }
                            }
                          : null,
                      onReportTap: () => _showGroupFeedReport(item),
                      onHideTap: detail.isAdmin
                          ? () async {
                              await CommunityService.setFeedItemVisibility(
                                item.feedItemId,
                                isHidden: true,
                              );
                              await _load();
                            }
                          : null,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showGroupFeedReport(CommunityFeedItem item) async {
    final result = await _showReportDialog(context);
    if (result == null) return;
    try {
      await CommunityService.createReport(
        targetType: 'feed_item',
        targetId: item.feedItemId,
        reason: result['reason'] as String,
        details: result['details'] as String?,
      );
      if (!mounted) return;
      AppToast.show(context, 'Report submitted.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openGroupReports() async {
    final detail = _detail;
    if (detail == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityAdminReportsPage(
          groupId: detail.id,
          title: '${detail.name} Reports',
        ),
      ),
    );
    await _load();
  }

  Future<void> _archiveGroup() async {
    final detail = _detail;
    if (detail == null) return;
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Archive group',
      message: 'This will archive the group and remove it from normal community use.',
      confirmText: 'Archive',
      borderColor: Colors.redAccent,
    );
    if (confirm != true) return;
    try {
      await CommunityService.archiveGroup(detail.id);
      if (!mounted) return;
      AppToast.show(context, 'Group archived.', type: AppToastType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }
}

class CommunityChallengesPage extends StatefulWidget {
  const CommunityChallengesPage({
    super.key,
    required this.canAdminManage,
  });

  final bool canAdminManage;

  @override
  State<CommunityChallengesPage> createState() => _CommunityChallengesPageState();
}

class _CommunityChallengesPageState extends State<CommunityChallengesPage> {
  List<CommunityChallenge> _challenges = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final challenges = await CommunityService.fetchChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleMute(CommunityChallenge challenge, bool muted) async {
    try {
      await CommunityService.updateChallengeNotifications(
        challenge.challengeId,
        muted: muted,
      );
      if (!mounted) return;
      setState(() {
        _challenges = _challenges
            .map(
              (item) => item.challengeId == challenge.challengeId
                  ? item.copyWith(mutedNotifications: muted)
                  : item,
            )
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _createChallenge() async {
    final payload = await _showChallengeEditor(context, null);
    if (payload == null) return;
    try {
      await CommunityService.createChallenge(
        name: payload.name,
        description: payload.description,
        challengeType: payload.challengeType,
        startAtIso: payload.startAtIso,
        endAtIso: payload.endAtIso,
        goalValue: payload.goalValue,
        progressUnit: payload.progressUnit,
        isActive: payload.isActive,
      );
      if (!mounted) return;
      AppToast.show(context, 'Challenge created.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _editChallenge(CommunityChallenge challenge) async {
    final payload = await _showChallengeEditor(context, challenge);
    if (payload == null) return;
    try {
      await CommunityService.updateChallenge(
        challenge.challengeId,
        name: payload.name,
        description: payload.description,
        startAtIso: payload.startAtIso,
        endAtIso: payload.endAtIso,
        goalValue: payload.goalValue,
        progressUnit: payload.progressUnit,
        isActive: payload.isActive,
      );
      if (!mounted) return;
      AppToast.show(context, 'Challenge updated.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('Community Challenges'),
        actions: [
          if (widget.canAdminManage)
            IconButton(
              onPressed: _createChallenge,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load challenges',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (_challenges.isEmpty)
              const _CommunityEmptyCard(
                title: 'No challenges right now',
                message: 'Global community challenges will appear here automatically when launched.',
              )
            else
              ..._challenges.map(
                (challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MiniChip(label: challenge.challengeType.replaceAll('_', ' ')),
                            const Spacer(),
                            if (widget.canAdminManage)
                              IconButton(
                                onPressed: () => _editChallenge(challenge),
                                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                              ),
                          ],
                        ),
                        Text(
                          challenge.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((challenge.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            challenge.description!,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (challenge.progressPercent / 100).clamp(0, 1),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            challenge.isCompleted ? Colors.greenAccent : AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${challenge.progressPercent.toStringAsFixed(0)}% complete',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            Switch.adaptive(
                              activeColor: AppColors.accent,
                              value: challenge.mutedNotifications,
                              onChanged: (value) => _toggleMute(challenge, value),
                            ),
                          ],
                        ),
                        if (challenge.startAt != null || challenge.endAt != null)
                          Text(
                            '${challenge.startAt != null ? _formatDate(challenge.startAt) : '-'} -> ${challenge.endAt != null ? _formatDate(challenge.endAt) : '-'}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityBadgesPage extends StatefulWidget {
  const CommunityBadgesPage({super.key});

  @override
  State<CommunityBadgesPage> createState() => _CommunityBadgesPageState();
}

class _CommunityBadgesPageState extends State<CommunityBadgesPage> {
  List<CommunityBadge> _allBadges = const [];
  List<CommunityBadge> _earnedBadges = const [];
  bool _loading = true;
  String? _error;
  bool _showEarnedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final badges = await CommunityService.fetchBadges();
      final earned = await CommunityService.fetchEarnedBadges();
      if (!mounted) return;
      setState(() {
        _allBadges = badges;
        _earnedBadges = earned;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _showEarnedOnly ? _earnedBadges : _allBadges;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: const Text('Badges'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                _FeedFilterChip(
                  label: 'All badges',
                  selected: !_showEarnedOnly,
                  onTap: () => setState(() => _showEarnedOnly = false),
                ),
                const SizedBox(width: 8),
                _FeedFilterChip(
                  label: 'Earned',
                  selected: _showEarnedOnly,
                  onTap: () => setState(() => _showEarnedOnly = true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load badges',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (items.isEmpty)
              const _CommunityEmptyCard(
                title: 'No badges yet',
                message: 'Your earned community milestones will appear here automatically.',
              )
            else
              ...items.map(
                (badge) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardContainer(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: badge.isEarned
                                ? const Color(0xFFD4AF37).withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            badge.isEarned ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                            color: badge.isEarned ? const Color(0xFFD4AF37) : Colors.white54,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      badge.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _MiniChip(label: badge.category),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                badge.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.4,
                                ),
                              ),
                              if (badge.awardedAt != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Earned ${_formatDate(badge.awardedAt)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityAdminReportsPage extends StatefulWidget {
  const CommunityAdminReportsPage({
    super.key,
    this.groupId,
    this.title = 'Moderation Reports',
  });

  final int? groupId;
  final String title;

  @override
  State<CommunityAdminReportsPage> createState() => _CommunityAdminReportsPageState();
}

class _CommunityAdminReportsPageState extends State<CommunityAdminReportsPage> {
  List<CommunityReport> _reports = const [];
  bool _loading = true;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = widget.groupId == null
          ? await CommunityService.fetchAdminReports(status: _status)
          : await CommunityService.fetchGroupReports(widget.groupId!, status: _status);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _review(CommunityReport report, String status) async {
    try {
      await CommunityService.reviewReport(report.reportId, status: status);
      if (!mounted) return;
      AppToast.show(context, 'Report updated.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _moderate(CommunityReport report, String action) async {
    try {
      if (report.targetType == 'feed_item') {
        await CommunityService.setFeedItemVisibility(report.targetId, isHidden: true);
      } else {
        await CommunityService.setCommentStatus(report.targetId, status: action);
      }
      if (!mounted) return;
      AppToast.show(context, 'Moderation action applied.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeedFilterChip(
                  label: 'All',
                  selected: _status == null,
                  onTap: () async {
                    setState(() => _status = null);
                    await _load();
                  },
                ),
                ...['open', 'reviewing', 'resolved', 'dismissed'].map(
                  (status) => _FeedFilterChip(
                    label: status,
                    selected: _status == status,
                    onTap: () async {
                      setState(() => _status = status);
                      await _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const _CommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load moderation queue',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (_reports.isEmpty)
              const _CommunityEmptyCard(
                title: 'No reports',
                message: 'The moderation queue is currently clear.',
              )
            else
              ..._reports.map(
                (report) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniChip(label: report.status),
                            _MiniChip(label: report.targetType),
                            _MiniChip(label: report.reason),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Target #${report.targetId}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if ((report.details ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            report.details!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _review(report, 'reviewing'),
                              child: const Text('Mark reviewing'),
                            ),
                            OutlinedButton(
                              onPressed: () => _review(report, 'dismissed'),
                              child: const Text('Dismiss'),
                            ),
                            ElevatedButton(
                              onPressed: () => _review(report, 'resolved'),
                              child: const Text('Resolve'),
                            ),
                            if (report.targetType == 'feed_item')
                              OutlinedButton(
                                onPressed: () => _moderate(report, 'hidden'),
                                child: const Text('Hide item'),
                              ),
                            if (report.targetType == 'comment')
                              OutlinedButton(
                                onPressed: () => _moderate(report, 'blocked'),
                                child: const Text('Block comment'),
                              ),
                            if (report.targetType == 'comment')
                              OutlinedButton(
                                onPressed: () => _moderate(report, 'deleted'),
                                child: const Text('Delete comment'),
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
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.feedItem});

  final CommunityFeedItem feedItem;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<CommunityComment> _comments = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await CommunityService.fetchComments(widget.feedItem.feedItemId);
      if (!mounted) return;
      setState(() {
        _comments = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final comment = await CommunityService.createComment(widget.feedItem.feedItemId, text);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _comments = [comment, ..._comments];
        _submitting = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _reportComment(CommunityComment comment) async {
    final result = await _showReportDialog(context);
    if (result == null) return;
    try {
      await CommunityService.createReport(
        targetType: 'comment',
        targetId: comment.commentId,
        reason: result['reason'] as String,
        details: result['details'] as String?,
      );
      if (!mounted) return;
      AppToast.show(context, 'Comment reported.', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0B0B0B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comments',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _Avatar(
                                              url: comment.author.avatarUrl,
                                              label: comment.author.primaryLabel,
                                              radius: 16,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                comment.author.primaryLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _formatDate(comment.createdAt),
                                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                                            ),
                                            IconButton(
                                              onPressed: () => _reportComment(comment),
                                              icon: const Icon(Icons.flag_outlined, color: Colors.white54),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          comment.commentText,
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.8),
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GroupMembersSheet extends StatefulWidget {
  const _GroupMembersSheet({
    required this.groupId,
    required this.groupName,
    required this.canAdminManage,
  });

  final int groupId;
  final String groupName;
  final bool canAdminManage;

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  List<CommunityMembership> _members = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await CommunityService.fetchGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(CommunityMembership member) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Remove member',
      message: 'This will remove ${member.displayName} from the group.',
      confirmText: 'Remove',
      borderColor: Colors.redAccent,
    );
    if (confirm != true) return;
    try {
      await CommunityService.removeGroupMember(widget.groupId, member.userId);
      if (!mounted) return;
      AppToast.show(context, 'Member removed.', type: AppToastType.success);
      await _load();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _setRole(CommunityMembership member, String role) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: role == 'admin' ? 'Make admin' : 'Make member',
      message: role == 'admin'
          ? 'Give ${member.displayName} admin access for this community.'
          : 'Remove admin access from ${member.displayName}.',
      confirmText: role == 'admin' ? 'Promote' : 'Demote',
    );
    if (confirm != true) return;
    try {
      await CommunityService.updateGroupMemberRole(
        widget.groupId,
        member.userId,
        role: role,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        role == 'admin' ? 'Member promoted.' : 'Member demoted.',
        type: AppToastType.success,
      );
      await _load();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _transferAdmin(CommunityMembership member) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Transfer ownership',
      message: 'Make ${member.displayName} the new group admin.',
      confirmText: 'Transfer',
    );
    if (confirm != true) return;
    try {
      await CommunityService.transferAdmin(widget.groupId, member.userId);
      if (!mounted) return;
      AppToast.show(context, 'Admin transferred.', type: AppToastType.success);
      await _load();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E0E0E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.groupName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Members',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      _Avatar(
                                        url: member.avatarUrl,
                                        label: member.displayName,
                                        radius: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member.displayName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${member.role} · ${member.status}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.canAdminManage && member.status == 'active')
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_horiz, color: Colors.white70),
                                          color: const Color(0xFF141414),
                                          onSelected: (value) async {
                                            if (value == 'promote') {
                                              await _setRole(member, 'admin');
                                            } else if (value == 'demote') {
                                              await _setRole(member, 'member');
                                            } else if (value == 'transfer') {
                                              await _transferAdmin(member);
                                            } else if (value == 'remove') {
                                              await _remove(member);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            if (member.role != 'admin')
                                              const PopupMenuItem(value: 'promote', child: Text('Make admin')),
                                            if (member.role == 'admin')
                                              const PopupMenuItem(value: 'demote', child: Text('Make member')),
                                            const PopupMenuItem(value: 'transfer', child: Text('Transfer admin')),
                                            const PopupMenuItem(value: 'remove', child: Text('Remove member')),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupFeedCard extends StatelessWidget {
  const _GroupFeedCard({
    required this.item,
    required this.canAdminManage,
    this.onCommentsTap,
    this.onReportTap,
    this.onHideTap,
  });

  final CommunityFeedItem item;
  final bool canAdminManage;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onReportTap;
  final VoidCallback? onHideTap;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(url: item.actor.avatarUrl, label: item.actor.primaryLabel),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.actor.primaryLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                color: const Color(0xFF141414),
                onSelected: (value) {
                  if (value == 'report') {
                    onReportTap?.call();
                  } else if (value == 'hide') {
                    onHideTap?.call();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                  if (canAdminManage)
                    const PopupMenuItem(value: 'hide', child: Text('Hide')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.event.title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if ((item.event.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.event.subtitle!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.favorite_border, color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text('${item.likeCount}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 18),
              InkWell(
                onTap: onCommentsTap,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: item.canComment ? Colors.white54 : Colors.white24,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.commentCount}',
                      style: TextStyle(
                        color: item.canComment ? Colors.white70 : Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent ? AppColors.accent : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.accent.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent ? AppColors.accent : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accent ? AppColors.accent : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({required this.group});

  final CommunityGroupSummary group;

  @override
  Widget build(BuildContext context) {
    final isPrivate = group.isPrivate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPrivate
            ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
            : const Color(0xFF0EA5A4).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_outline : Icons.public_outlined,
            size: 16,
            color: isPrivate ? const Color(0xFFC4B5FD) : const Color(0xFF5EEAD4),
          ),
          const SizedBox(width: 6),
          Text(
            group.groupKind ?? group.visibility ?? 'group',
            style: TextStyle(
              color: isPrivate ? const Color(0xFFE9D5FF) : const Color(0xFF99F6E4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedFilterChip extends StatelessWidget {
  const _FeedFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.accent : Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FeedActionButton extends StatelessWidget {
  const _FeedActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final activeColor = accent ? Colors.pinkAccent : Colors.white;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: enabled ? activeColor : Colors.white24),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: enabled ? activeColor : Colors.white24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PayloadChip extends StatelessWidget {
  const _PayloadChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'inherit'),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.label,
    this.radius = 20,
  });

  final String? url;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(
              label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    this.onTap,
  });

  final CommunityChallenge challenge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MiniChip(label: challenge.challengeType.replaceAll('_', ' ')),
                const Spacer(),
                if (challenge.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              challenge.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (challenge.progressPercent / 100).clamp(0, 1),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                challenge.isCompleted ? Colors.greenAccent : AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${challenge.progressPercent.toStringAsFixed(0)}% complete',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineSectionHeader extends StatelessWidget {
  const _InlineSectionHeader({
    required this.title,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null && onTap != null)
          TextButton(
            onPressed: onTap,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _CommunityLoadingCard extends StatelessWidget {
  const _CommunityLoadingCard();

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        children: const [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Loading community...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _CommunityEmptyCard extends StatelessWidget {
  const _CommunityEmptyCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        children: [
          const Icon(Icons.groups_2_outlined, size: 32, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareToggleTile extends StatelessWidget {
  const _ShareToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.accent,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _CreateGroupPayload {
  const _CreateGroupPayload({
    required this.name,
    required this.visibility,
    required this.groupKind,
    this.description,
    this.isDiscoverable,
  });

  final String name;
  final String visibility;
  final String groupKind;
  final String? description;
  final bool? isDiscoverable;
}

class _PinEditorResult {
  const _PinEditorResult({
    required this.pinType,
    required this.title,
    required this.body,
    required this.sortOrder,
  });

  final String pinType;
  final String title;
  final String body;
  final int sortOrder;
}

class _ChallengeEditorResult {
  const _ChallengeEditorResult({
    required this.name,
    required this.challengeType,
    required this.startAtIso,
    required this.endAtIso,
    required this.isActive,
    this.description,
    this.goalValue,
    this.progressUnit,
  });

  final String name;
  final String challengeType;
  final String startAtIso;
  final String endAtIso;
  final bool isActive;
  final String? description;
  final double? goalValue;
  final String? progressUnit;
}

Future<String?> _showJoinCodeDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: const Text('Join by code', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: '6-digit code',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Join'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null || result.length != 6) return null;
  return result;
}

Future<void> _showGroupCodeDialog(
  BuildContext context, {
  required String title,
  required String code,
  String? message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null && message.trim().isNotEmpty) ...[
            Text(
              message,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.74)),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<_CreateGroupPayload?> _showCreateGroupDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  String visibility = 'private';
  String kind = 'general';
  bool discoverable = true;
  final result = await showDialog<_CreateGroupPayload>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text('Create community', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Group name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: visibility,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => visibility = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: kind,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General')),
                      DropdownMenuItem(value: 'gym', child: Text('Gym')),
                      DropdownMenuItem(value: 'coach', child: Text('Coach')),
                      DropdownMenuItem(value: 'city', child: Text('City')),
                      DropdownMenuItem(value: 'country', child: Text('Country')),
                      DropdownMenuItem(value: 'sport', child: Text('Sport')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => kind = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Discoverable',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    value: visibility == 'public' ? discoverable : false,
                    onChanged: visibility == 'public'
                        ? (value) => setState(() => discoverable = value)
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.length < 3) return;
                  Navigator.pop(
                    context,
                    _CreateGroupPayload(
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      visibility: visibility,
                      groupKind: kind,
                      isDiscoverable: visibility == 'public' ? discoverable : false,
                    ),
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  nameController.dispose();
  descriptionController.dispose();
  return result;
}

Future<_CreateGroupPayload?> _showEditGroupDialog(
  BuildContext context,
  CommunityGroupDetail detail,
) async {
  final nameController = TextEditingController(text: detail.name);
  final descriptionController = TextEditingController(text: detail.description ?? '');
  String visibility = detail.visibility ?? 'private';
  String kind = detail.groupKind ?? 'general';
  bool discoverable = detail.isDiscoverable;
  final result = await showDialog<_CreateGroupPayload>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text('Edit group', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Group name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: visibility,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'public', child: Text('Public')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => visibility = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: kind,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General')),
                      DropdownMenuItem(value: 'gym', child: Text('Gym')),
                      DropdownMenuItem(value: 'coach', child: Text('Coach')),
                      DropdownMenuItem(value: 'city', child: Text('City')),
                      DropdownMenuItem(value: 'country', child: Text('Country')),
                      DropdownMenuItem(value: 'sport', child: Text('Sport')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => kind = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Discoverable',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    value: visibility == 'public' ? discoverable : false,
                    onChanged: visibility == 'public'
                        ? (value) => setState(() => discoverable = value)
                        : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.length < 3) return;
                  Navigator.pop(
                    context,
                    _CreateGroupPayload(
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      visibility: visibility,
                      groupKind: kind,
                      isDiscoverable: visibility == 'public' ? discoverable : false,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  nameController.dispose();
  descriptionController.dispose();
  return result;
}

Future<Map<String, String?>?> _showReportDialog(BuildContext context) async {
  final detailsController = TextEditingController();
  String reason = 'other';
  final result = await showDialog<Map<String, String?>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: const Text('Report content', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: reason,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                      DropdownMenuItem(value: 'spam', child: Text('Spam')),
                      DropdownMenuItem(value: 'contact_info', child: Text('Contact info')),
                      DropdownMenuItem(value: 'abuse', child: Text('Abuse')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => reason = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: detailsController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Optional details',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  {
                    'reason': reason,
                    'details': detailsController.text.trim().isEmpty
                        ? null
                        : detailsController.text.trim(),
                  },
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
  detailsController.dispose();
  return result;
}

Future<String?> _showMetricPicker(BuildContext context, String current) async {
  final metrics = const [
    'workout_streak',
    'activity_streak',
    'score_streak_80',
    'strain_week',
    'volume_week',
    'steps_week',
  ];
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF111111),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Choose leaderboard metric',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...metrics.map(
            (metric) => ListTile(
              title: Text(
                metric.replaceAll('_', ' '),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: metric == current
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(context, metric),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<_PinEditorResult?> _showPinEditor(
  BuildContext context,
  CommunityPin? existing,
) async {
  final titleController = TextEditingController(text: existing?.title ?? '');
  final bodyController = TextEditingController(text: existing?.body ?? '');
  final sortOrderController = TextEditingController(
    text: '${existing?.sortOrder ?? 0}',
  );
  String pinType = existing?.pinType ?? 'expert_tip';
  final result = await showDialog<_PinEditorResult>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: Text(
              existing == null ? 'Create pin' : 'Edit pin',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: pinType,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'expert_tip', child: Text('Expert tip')),
                      DropdownMenuItem(value: 'challenge_rule', child: Text('Challenge rule')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => pinType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Pinned content'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Sort order'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final body = bodyController.text.trim();
                  if (title.length < 3 || body.length < 3) return;
                  Navigator.pop(
                    context,
                    _PinEditorResult(
                      pinType: pinType,
                      title: title,
                      body: body,
                      sortOrder: int.tryParse(sortOrderController.text.trim()) ?? 0,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  titleController.dispose();
  bodyController.dispose();
  sortOrderController.dispose();
  return result;
}

Future<_ChallengeEditorResult?> _showChallengeEditor(
  BuildContext context,
  CommunityChallenge? existing,
) async {
  final nameController = TextEditingController(text: existing?.name ?? '');
  final descriptionController = TextEditingController(text: existing?.description ?? '');
  final goalController = TextEditingController(
    text: existing?.goalValue?.toStringAsFixed(0) ?? '',
  );
  final unitController = TextEditingController(text: existing?.progressUnit ?? '');
  String type = existing?.challengeType ?? 'workout_days';
  bool isActive = existing?.isActive ?? true;
  DateTime startDate = existing?.startAt ?? DateTime.now();
  DateTime endDate = existing?.endAt ?? DateTime.now().add(const Duration(days: 30));
  final result = await showDialog<_ChallengeEditorResult>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startDate,
              firstDate: DateTime(2025),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setState(() => startDate = picked);
            }
          }

          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: endDate,
              firstDate: DateTime(2025),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              setState(() => endDate = picked);
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: Text(
              existing == null ? 'Create challenge' : 'Edit challenge',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Challenge name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(value: 'workout_days', child: Text('Workout days')),
                      DropdownMenuItem(value: 'movement_total', child: Text('Movement total')),
                      DropdownMenuItem(value: 'cardio_sessions', child: Text('Cardio sessions')),
                      DropdownMenuItem(value: 'score_threshold_days', child: Text('Score threshold days')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: pickStart,
                          child: Text('Start ${DateFormat('MMM d').format(startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: pickEnd,
                          child: Text('End ${DateFormat('MMM d').format(endDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Goal value'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Progress unit'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Active',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.length < 3) return;
                  Navigator.pop(
                    context,
                    _ChallengeEditorResult(
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      challengeType: type,
                      startAtIso: _startOfDayIso(startDate),
                      endAtIso: _endOfDayIso(endDate),
                      goalValue: double.tryParse(goalController.text.trim()),
                      progressUnit: unitController.text.trim().isEmpty
                          ? null
                          : unitController.text.trim(),
                      isActive: isActive,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  nameController.dispose();
  descriptionController.dispose();
  goalController.dispose();
  unitController.dispose();
  return result;
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) return '-';
  return DateFormat('MMM d').format(dateTime.toLocal());
}

String _startOfDayIso(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
  return utc.toIso8601String();
}

String _endOfDayIso(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day, 23, 59, 59);
  return utc.toIso8601String();
}
