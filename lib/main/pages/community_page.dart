import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/account_storage.dart';
import '../../services/community/community_models.dart';
import '../../services/community/community_service.dart';
import '../../theme/app_theme.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../widgets/confirm_dialog.dart';
import '../../TaqaUI/components/taqa_community_hero_card.dart';
import '../../TaqaUI/components/taqa_community_action_row.dart';
import '../../TaqaUI/components/taqa_community_section_header.dart';
import '../../TaqaUI/components/taqa_community_group_card.dart';
import '../../TaqaUI/components/taqa_community_group_hero_card.dart';
import '../../TaqaUI/components/taqa_mute_notifications_card.dart';
import '../../TaqaUI/components/taqa_settings_row_card.dart';
import '../../TaqaUI/components/taqa_leaderboard_card.dart';
import '../../TaqaUI/components/taqa_value_dialog.dart';
import '../../TaqaUI/components/taqa_community_challenge_card.dart';
import '../../TaqaUI/components/taqa_community_feed_card.dart';
import '../../TaqaUI/components/taqa_community_filter_chip.dart';
import '../../TaqaUI/components/taqa_community_group_list_card.dart';
import '../../TaqaUI/components/taqa_search_field.dart';
import '../../TaqaUI/styles/taqa_ui_scale.dart';
import '../../TaqaUI/styles/taqa_ui_styles.dart';
import '../../TaqaUI/taqa_ui_colors.dart';
import '../../TaqaUI/components/taqa_steps_ui.dart' show TaqaRangeTab;

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  CommunityBootstrap? _bootstrap;
  List<CommunityFeedItem> _feed = const [];
  List<CommunityBadge> _myEarnedBadges = const [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _selectedGroupId;
  int? _pickedGroupId;
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
      final feedPage = await CommunityService.fetchFeed(
        groupId: _selectedGroupId,
      );
      var earned = const <CommunityBadge>[];
      try {
        earned = await CommunityService.fetchEarnedBadges();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _feed = feedPage.items;
        _nextCursor = feedPage.nextCursor;
        _loading = false;
        _myEarnedBadges = earned;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _myEarnedBadges = const [];
      });
    }
  }

  Future<void> _refreshFeed() async {
    try {
      final bootstrap = await CommunityService.fetchBootstrap();
      final feedPage = await CommunityService.fetchFeed(
        groupId: _selectedGroupId,
      );
      var earned = _myEarnedBadges;
      try {
        earned = await CommunityService.fetchEarnedBadges();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _bootstrap = bootstrap;
        _feed = feedPage.items;
        _nextCursor = feedPage.nextCursor;
        _error = null;
        _myEarnedBadges = earned;
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
        : item.copyWith(currentUserLiked: true, likeCount: item.likeCount + 1);
    setState(() {
      _feed = _feed
          .map(
            (feedItem) =>
                feedItem.feedItemId == item.feedItemId ? updated : feedItem,
          )
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
            .map(
              (feedItem) =>
                  feedItem.feedItemId == item.feedItemId ? item : feedItem,
            )
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
    return _bootstrap?.joinedGroups.any(
          (group) => group.id == groupId && group.isAdmin,
        ) ==
        true;
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
        _feed = _feed
            .where((entry) => entry.feedItemId != item.feedItemId)
            .toList(growable: false);
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
      AppToast.show(
        context,
        'Joined ${group.name}.',
        type: AppToastType.success,
      );
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

  Future<void> _openMyGroups(List<CommunityGroupSummary> groups) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityMyGroupsPage(groups: groups)),
    );
    await _refreshFeed();
  }

  Future<void> _openChallenges() async {
    final canPlatformAdminManage = _bootstrap?.hasPlatformAdminAccess ?? false;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChallengesPage(
          title: 'Global Challenges',
          emptyMessage:
              'Global community challenges will appear here automatically when launched.',
          canManageGlobalChallenges: canPlatformAdminManage,
        ),
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
                message:
                    'Join groups, share your data, and your real activity will start populating the feed.',
              )
            else
              ..._feed.map(_buildFeedCard),
            if (_nextCursor != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _loadingMore ? null : _loadMore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TaqaUiColors.charcoal,
                  side: BorderSide(
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.18),
                  ),
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
    return TaqaCommunityHeroCard(
      welcomeText: bootstrap == null
          ? 'Loading your groups'
          : 'Welcome back, ${bootstrap.currentUser.primaryLabel}',
      badgeCount: _myEarnedBadges.length,
      groupCount: bootstrap?.joinedGroups.length ?? 0,
      challengeCount: bootstrap?.activeChallenges.length ?? 0,
      reportCount: bootstrap?.unreadModerationReportNoticesCount ?? 0,
      onBadgesTap: _openBadges,
      onGroupsTap: _openDiscover,
      onChallengesTap: _openChallenges,
      onReportsTap: _openAdminReports,
    );
  }

  Widget _buildQuickActions() {
    return TaqaCommunityActionRow(
      onDiscoverTap: _openDiscover,
      onJoinByCodeTap: _joinByCode,
      onCreateGroupTap: _createGroup,
    );
  }

  Widget _buildJoinedGroupsSection() {
    final groups = _bootstrap?.joinedGroups ?? const <CommunityGroupSummary>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaCommunitySectionHeader(
          title: 'Your Groups',
          actionLabel: 'Open all',
          onActionTap: () => _openMyGroups(groups),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const _CommunityEmptyCard(
            title: 'No groups yet',
            message: 'Create a private group or discover a public community.',
          )
        else
          SizedBox(
            height: TaqaUiStyles.communityGroupCardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) => SizedBox(width: TaqaUiScale.w(15)),
              itemBuilder: (context, index) =>
                  _buildJoinedGroupCard(groups[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildJoinedGroupCard(CommunityGroupSummary group) {
    return TaqaCommunityGroupCard(
      tag: group.groupKind ?? group.visibility ?? 'Group',
      name: group.name,
      description: group.description ?? '',
      memberCount: group.memberCount,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityGroupDetailPage(groupId: group.id),
          ),
        );
        await _refreshFeed();
      },
    );
  }

  Widget _buildChallengePreview() {
    final challenges =
        _bootstrap?.activeChallenges ?? const <CommunityChallenge>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaqaCommunitySectionHeader(
          title: 'Active Challenges',
          actionLabel: 'Open all',
          onActionTap: _openChallenges,
        ),
        const SizedBox(height: 24),
        if (challenges.isEmpty)
          const _CommunityEmptyCard(
            title: 'No active challenges',
            message:
                'Global community challenges will appear here when launched.',
          )
        else
          ...challenges
              .take(3)
              .map(
                (challenge) => Padding(
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(15)),
                  child: TaqaCommunityChallengeCard(
                    tag: challenge.challengeType.replaceAll('_', ' '),
                    name: challenge.name,
                    progress: challenge.progressPercent / 100,
                    onTap: _openChallenges,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildFeedFilterBar() {
    final groups = _bootstrap?.joinedGroups ?? const <CommunityGroupSummary>[];
    final gap = TaqaUiScale.w(15);
    CommunityGroupSummary? pickedGroup;
    if (groups.isNotEmpty) {
      pickedGroup = groups.firstWhere(
        (group) => group.id == _pickedGroupId,
        orElse: () => groups.first,
      );
    }
    final target = pickedGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaqaCommunitySectionHeader(title: 'Feed'),
        const SizedBox(height: 24),
        SizedBox(
          height: TaqaUiStyles.actionButtonHeight,
          child: Row(
            children: [
              Expanded(
                child: TaqaRangeTab(
                  label: 'All groups',
                  selected: _selectedGroupId == null,
                  onTap: () async {
                    setState(() => _selectedGroupId = null);
                    await _refreshFeed();
                  },
                ),
              ),
              if (target != null) ...[
                SizedBox(width: gap),
                Expanded(
                  child: _GroupPickerTab(
                    label: target.name,
                    selected: _selectedGroupId == target.id,
                    onSelect: () async {
                      setState(() {
                        _pickedGroupId = target.id;
                        _selectedGroupId = target.id;
                      });
                      await _refreshFeed();
                    },
                    onPick: () => _pickFeedGroup(groups, target.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFeedGroup(
    List<CommunityGroupSummary> groups,
    int current,
  ) async {
    final picked = await _showGroupPicker(context, groups, current);
    if (picked == null) return;
    setState(() {
      _pickedGroupId = picked;
      _selectedGroupId = picked;
    });
    await _refreshFeed();
  }

  Widget _buildFeedCard(CommunityFeedItem item) {
    final isAdmin = _isAdminForGroup(item.group.id);
    return Padding(
      padding: EdgeInsets.only(bottom: TaqaUiScale.h(15)),
      child: TaqaCommunityFeedCard(
        actorLabel: item.actor.primaryLabel,
        actorAvatarUrl: item.actor.avatarUrl,
        chips: [
          item.group.name,
          item.event.type.replaceAll('_', ' '),
          if (item.event.occurredAt != null) _formatDate(item.event.occurredAt),
        ],
        title: item.event.title,
        subtitle: item.event.subtitle,
        payloadEntries: _buildPayloadEntries(item.event.payload),
        liked: item.currentUserLiked,
        likeCount: item.likeCount,
        commentCount: item.commentCount,
        canComment: item.canComment,
        onLikeTap: () => _toggleLike(item),
        onCommentTap: () => _openComments(item),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: TaqaUiColors.charcoal),
          color: TaqaUiColors.white,
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
            const PopupMenuItem<String>(value: 'report', child: Text('Report')),
            if (isAdmin)
              const PopupMenuItem<String>(
                value: 'hide',
                child: Text('Hide from group'),
              ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, String>> _buildPayloadEntries(
    Map<String, dynamic> payload,
  ) {
    final entries = <MapEntry<String, String>>[];
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
      entries.add(MapEntry(key.replaceAll('_', ' '), value.toString()));
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
  Timer? _searchDebounce;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _groupKind;
  int? _nextCursor;

  static const List<String?> _groupKindOptions = [
    null,
    'general',
    'gym',
    'coach',
    'city',
    'country',
    'sport',
  ];

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

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: const Text('Discover Communities'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TaqaSearchField(
              controller: _searchController,
              hint: 'Search by name or description',
              onChanged: _onSearchChanged,
              onSubmitted: (_) => _load(),
            ),
            SizedBox(height: TaqaUiScale.h(15)),
            TaqaCommunityFilterGrid(
              labels: const [
                'All kinds',
                'General',
                'Gym',
                'Coach',
                'City',
                'Country',
                'Sport',
              ],
              selectedIndex: _groupKindOptions.indexOf(_groupKind),
              onSelected: (index) async {
                setState(() => _groupKind = _groupKindOptions[index]);
                await _load();
              },
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
                message:
                    'Try a broader search or create your own private community.',
              )
            else
              ..._groups.map(
                (group) => Padding(
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(15)),
                  child: TaqaCommunityGroupListCard(
                    tag: group.groupKind ?? group.visibility ?? 'Group',
                    name: group.name,
                    description: group.description ?? '',
                    memberCount: group.memberCount,
                    trailing: group.isJoined
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Joined',
                              style: TextStyle(
                                color: TaqaUiColors.charcoal,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _openGroup(group),
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
    return scaffold;
  }
}

class CommunityGroupDetailPage extends StatefulWidget {
  const CommunityGroupDetailPage({super.key, required this.groupId});

  final int groupId;

  @override
  State<CommunityGroupDetailPage> createState() =>
      _CommunityGroupDetailPageState();
}

class _CommunityGroupDetailPageState extends State<CommunityGroupDetailPage> {
  CommunityGroupDetail? _detail;
  List<CommunityFeedItem> _feed = const [];
  List<CommunityMembership> _members = const [];
  List<CommunityChallenge> _groupChallenges = const [];
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
      final groupChallenges = detail.isJoined
          ? await CommunityService.fetchChallenges(groupId: widget.groupId)
          : const <CommunityChallenge>[];
      final currentUserId = await AccountStorage.getUserId();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _feed = feed.items;
        _members = members;
        _groupChallenges = groupChallenges;
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
    required CommunityShareSettings Function(CommunityShareSettings settings)
    nextSettings,
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
      final updated = await CommunityService.updateShareSettings(
        widget.groupId,
        optimistic,
      );
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
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Leave group',
      message:
          'You can rejoin later if the group is public or if you still have the private code.',
      confirmLabel: 'Leave',
    );
    if (!confirm) return;
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
      AppToast.show(
        context,
        'Joined ${group.name}.',
        type: AppToastType.success,
      );
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
          title: const Text(
            'New group code',
            style: TextStyle(color: Colors.white),
          ),
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
    final metric = await _showMetricPicker(
      context,
      detail.leaderboardMetric ?? 'workout_streak',
    );
    if (metric == null) return;
    try {
      await CommunityService.updateLeaderboardMetric(widget.groupId, metric);
      if (!mounted) return;
      AppToast.show(
        context,
        'Leaderboard metric updated.',
        type: AppToastType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _openLeaderboard() async {
    final detail = _detail;
    if (detail == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityLeaderboardPage(
          groupId: detail.id,
          isAdmin: detail.isAdmin,
          initialSummary: detail.leaderboardSummary,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openGroupChallenges() async {
    final detail = _detail;
    if (detail == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityChallengesPage(
          groupId: detail.id,
          title: '${detail.name} Challenges',
          emptyMessage:
              'Group challenges will appear here when created by this group admin.',
          canManageGroupChallenges: detail.isAdmin,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openPinnedItems() async {
    final detail = _detail;
    if (detail == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPinnedItemsPage(
          groupId: detail.id,
          isAdmin: detail.isAdmin,
          initialPins: detail.pinnedItems,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
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
      AppToast.show(
        context,
        'Notification preference saved.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final scaffold = Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
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
                } else if (value == 'challenges') {
                  await _openGroupChallenges();
                } else if (value == 'pin') {
                  await _openPinnedItems();
                } else if (value == 'reports') {
                  await _openGroupReports();
                } else if (value == 'archive') {
                  await _archiveGroup();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit group')),
                PopupMenuItem(
                  value: 'view_code',
                  child: Text('View join code'),
                ),
                PopupMenuItem(value: 'code', child: Text('Reset join code')),
                PopupMenuItem(value: 'members', child: Text('Manage members')),
                PopupMenuItem(value: 'reports', child: Text('Reports')),
                PopupMenuItem(
                  value: 'metric',
                  child: Text('Leaderboard metric'),
                ),
                PopupMenuItem(
                  value: 'challenges',
                  child: Text('Group challenges'),
                ),
                PopupMenuItem(value: 'pin', child: Text('Pinned items')),
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
              TaqaCommunityGroupHeroCard(
                tag: detail.groupKind ?? detail.visibility ?? 'Group',
                name: detail.name,
                description: detail.description ?? '',
                membersValue: '${detail.memberCount}',
                leaderboardValue: detail.leaderboardMetric ?? '-',
                onMembersTap: detail.isJoined ? _openMembers : null,
                actionIcon: detail.isJoined
                    ? Icons.exit_to_app
                    : (detail.isPrivate
                          ? Icons.lock_open_outlined
                          : Icons.group_add_outlined),
                onActionTap: detail.isJoined
                    ? _leaveGroup
                    : (detail.isPrivate ? _joinPrivateGroup : _joinPublicGroup),
              ),
              const SizedBox(height: 16),
              TaqaMuteNotificationsCard(
                value: _groupNotificationsMuted,
                onChanged: detail.isJoined ? _toggleNotifications : null,
              ),
              const SizedBox(height: 16),
              if (detail.shareSettings != null)
                TaqaSettingsRowCard(
                  title: 'Shared Metrics',
                  description:
                      'Choose exactly what this group can see from your real activity.',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommunitySharedMetricsPage(
                          initialSettings: detail.shareSettings!,
                          onToggle: (next) =>
                              _toggleShareSetting(nextSettings: next),
                        ),
                      ),
                    );
                  },
                ),
              if (detail.shareSettings != null) const SizedBox(height: 16),
              TaqaSettingsRowCard(
                title: 'Pinned Items',
                description: detail.pinnedItems.isEmpty
                    ? 'No pins yet.'
                    : '${detail.pinnedItems.length} pinned item${detail.pinnedItems.length == 1 ? '' : 's'}.',
                onTap: _openPinnedItems,
              ),
              const SizedBox(height: 15),
              TaqaSettingsRowCard(
                title: 'Challenges',
                description: !detail.isJoined
                    ? 'Join this group to view its group-specific challenges.'
                    : _groupChallenges.isEmpty
                    ? 'No group challenges yet.'
                    : '${_groupChallenges.length} active challenge${_groupChallenges.length == 1 ? '' : 's'}.',
                onTap: detail.isJoined ? _openGroupChallenges : null,
              ),
              const SizedBox(height: 16),
              TaqaLeaderboardCard(
                metricLabel: detail.leaderboardSummary.metric.replaceAll(
                  '_',
                  ' ',
                ),
                topEntries: detail.leaderboardSummary.items
                    .take(3)
                    .map(
                      (entry) => TaqaLeaderboardEntry(
                        rank: entry.rankPosition,
                        name: entry.displayName,
                      ),
                    )
                    .toList(growable: false),
                onTap: _openLeaderboard,
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
                  message:
                      'This group feed will populate from real workouts, badges, score improvements, movement, and challenges.',
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
    return scaffold;
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
      message:
          'This will archive the group and remove it from normal community use.',
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

class CommunityMyGroupsPage extends StatelessWidget {
  const CommunityMyGroupsPage({super.key, required this.groups});

  final List<CommunityGroupSummary> groups;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: const Text('Your Groups'),
      ),
      body: SafeArea(
        child: groups.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: _CommunityEmptyCard(
                  title: 'No groups yet',
                  message:
                      'Create a private group or discover a public community.',
                ),
              )
            : ListView.separated(
                padding: EdgeInsets.all(TaqaUiScale.w(20)),
                itemCount: groups.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: TaqaUiScale.h(15)),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return TaqaCommunityGroupHeroCard(
                    tag: group.groupKind ?? group.visibility ?? 'Group',
                    name: group.name,
                    description: group.description ?? '',
                    membersValue: '${group.memberCount}',
                    leaderboardValue: group.leaderboardMetric ?? '-',
                    onTap: () => _openGroupDetail(context, group),
                  );
                },
              ),
      ),
    );
  }

  void _openGroupDetail(BuildContext context, CommunityGroupSummary group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityGroupDetailPage(groupId: group.id),
      ),
    );
  }
}

class CommunityChallengesPage extends StatefulWidget {
  const CommunityChallengesPage({
    super.key,
    required this.title,
    required this.emptyMessage,
    this.groupId,
    this.canManageGlobalChallenges = false,
    this.canManageGroupChallenges = false,
  });

  final int? groupId;
  final String title;
  final String emptyMessage;
  final bool canManageGlobalChallenges;
  final bool canManageGroupChallenges;

  bool get isGroupScoped => groupId != null;
  bool get canCreate =>
      isGroupScoped ? canManageGroupChallenges : canManageGlobalChallenges;

  @override
  State<CommunityChallengesPage> createState() =>
      _CommunityChallengesPageState();
}

class _CommunityChallengesPageState extends State<CommunityChallengesPage> {
  List<CommunityChallenge> _globalChallenges = const [];
  List<CommunityChallenge> _groupChallenges = const [];
  bool _loading = true;
  String? _error;
  int _selectedTabIndex = 0;

  bool get _isGroupTab => widget.isGroupScoped && _selectedTabIndex == 1;
  bool get _canCreateForCurrentTab => _isGroupTab
      ? widget.canManageGroupChallenges
      : widget.canManageGlobalChallenges;
  List<CommunityChallenge> get _visibleChallenges =>
      _isGroupTab ? _groupChallenges : _globalChallenges;
  String get _currentEmptyMessage {
    if (_isGroupTab) {
      return 'Group challenges will appear here when created by this group admin.';
    }
    return widget.emptyMessage;
  }

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
      final globalChallenges = await CommunityService.fetchChallenges();
      final groupChallenges = widget.groupId == null
          ? const <CommunityChallenge>[]
          : await CommunityService.fetchChallenges(groupId: widget.groupId);
      if (!mounted) return;
      setState(() {
        _globalChallenges = globalChallenges;
        _groupChallenges = groupChallenges;
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
        _globalChallenges = _globalChallenges
            .map(
              (item) => item.challengeId == challenge.challengeId
                  ? item.copyWith(mutedNotifications: muted)
                  : item,
            )
            .toList(growable: false);
        _groupChallenges = _groupChallenges
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
      if (_isGroupTab && widget.groupId != null) {
        await CommunityService.createGroupChallenge(
          widget.groupId!,
          name: payload.name,
          description: payload.description,
          challengeType: payload.challengeType,
          startAtIso: payload.startAtIso,
          endAtIso: payload.endAtIso,
          goalValue: payload.goalValue,
          progressUnit: payload.progressUnit,
          isActive: payload.isActive,
        );
      } else {
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
      }
      if (!mounted) return;
      AppToast.show(context, 'Challenge created.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  bool _canManageChallenge(CommunityChallenge challenge) {
    if (challenge.isGroupScoped) return widget.canManageGroupChallenges;
    return widget.canManageGlobalChallenges;
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

  Future<void> _deleteChallenge(CommunityChallenge challenge) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: 'Delete challenge',
      message:
          'This will permanently remove the challenge and its progress records.',
      confirmText: 'Delete',
      borderColor: Colors.redAccent,
    );
    if (confirm != true) return;
    try {
      await CommunityService.deleteChallenge(challenge.challengeId);
      if (!mounted) return;
      AppToast.show(context, 'Challenge deleted.', type: AppToastType.success);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: Text(widget.title),
        actions: [
          if (_canCreateForCurrentTab)
            IconButton(
              onPressed: _createChallenge,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
        bottom: widget.isGroupScoped
            ? TabBar(
                onTap: (index) => setState(() => _selectedTabIndex = index),
                labelColor: TaqaUiColors.charcoal,
                unselectedLabelColor: TaqaUiColors.charcoal.withValues(
                  alpha: 0.6,
                ),
                tabs: const [
                  Tab(text: 'Global'),
                  Tab(text: 'Group'),
                ],
              )
            : null,
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
            else if (_visibleChallenges.isEmpty)
              _CommunityEmptyCard(
                title: 'No challenges right now',
                message: _currentEmptyMessage,
              )
            else
              ..._visibleChallenges.map(
                (challenge) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LightCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MiniChip(
                              label: challenge.challengeType.replaceAll(
                                '_',
                                ' ',
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MiniChip(
                              label: challenge.isGroupScoped
                                  ? 'group'
                                  : 'global',
                            ),
                            const Spacer(),
                            if (_canManageChallenge(challenge))
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_horiz,
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                color: const Color(0xFF141414),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    await _editChallenge(challenge);
                                  } else if (value == 'delete') {
                                    await _deleteChallenge(challenge);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Text(
                          challenge.name,
                          style: const TextStyle(
                            color: TaqaUiColors.charcoal,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((challenge.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            challenge.description!,
                            style: TextStyle(
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: (challenge.progressPercent / 100).clamp(0, 1),
                          backgroundColor: TaqaUiColors.charcoal.withValues(
                            alpha: 0.08,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            challenge.isCompleted
                                ? Colors.greenAccent
                                : AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${challenge.progressPercent.toStringAsFixed(0)}% complete',
                                style: TextStyle(
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              activeColor: AppColors.accent,
                              value: challenge.mutedNotifications,
                              onChanged: (value) =>
                                  _toggleMute(challenge, value),
                            ),
                          ],
                        ),
                        if (challenge.startAt != null ||
                            challenge.endAt != null)
                          Text(
                            '${challenge.startAt != null ? _formatDate(challenge.startAt) : '-'} -> ${challenge.endAt != null ? _formatDate(challenge.endAt) : '-'}',
                            style: TextStyle(
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.6,
                              ),
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
    if (!widget.isGroupScoped) {
      return scaffold;
    }
    return DefaultTabController(length: 2, child: scaffold);
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
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
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
                message:
                    'Your earned community milestones will appear here automatically.',
              )
            else
              ...items.map(
                (badge) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LightCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: badge.isEarned
                                ? const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.18)
                                : TaqaUiColors.charcoal.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            badge.isEarned
                                ? Icons.workspace_premium
                                : Icons.workspace_premium_outlined,
                            color: badge.isEarned
                                ? const Color(0xFFD4AF37)
                                : TaqaUiColors.charcoal.withValues(alpha: 0.54),
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
                                        color: TaqaUiColors.charcoal,
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
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.72,
                                  ),
                                  height: 1.4,
                                ),
                              ),
                              if (badge.awardedAt != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Earned ${_formatDate(badge.awardedAt)}',
                                  style: TextStyle(
                                    color: TaqaUiColors.charcoal.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                  ),
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
  State<CommunityAdminReportsPage> createState() =>
      _CommunityAdminReportsPageState();
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
          : await CommunityService.fetchGroupReports(
              widget.groupId!,
              status: _status,
            );
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
        await CommunityService.setFeedItemVisibility(
          report.targetId,
          isHidden: true,
        );
      } else {
        await CommunityService.setCommentStatus(
          report.targetId,
          status: action,
        );
      }
      if (!mounted) return;
      AppToast.show(
        context,
        'Moderation action applied.',
        type: AppToastType.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
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
                  child: _LightCard(
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
                            color: TaqaUiColors.charcoal,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        if ((report.details ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            report.details!,
                            style: TextStyle(
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.72,
                              ),
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
      final page = await CommunityService.fetchComments(
        widget.feedItem.feedItemId,
      );
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
      final comment = await CommunityService.createComment(
        widget.feedItem.feedItemId,
        text,
      );
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
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
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _reportComment(comment),
                                          icon: const Icon(
                                            Icons.flag_outlined,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      comment.commentText,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
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
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.canAdminManage &&
                                      member.status == 'active')
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_horiz,
                                        color: Colors.white70,
                                      ),
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
                                          const PopupMenuItem(
                                            value: 'promote',
                                            child: Text('Make admin'),
                                          ),
                                        if (member.role == 'admin')
                                          const PopupMenuItem(
                                            value: 'demote',
                                            child: Text('Make member'),
                                          ),
                                        const PopupMenuItem(
                                          value: 'transfer',
                                          child: Text('Transfer admin'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('Remove member'),
                                        ),
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
    return _LightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                url: item.actor.avatarUrl,
                label: item.actor.primaryLabel,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.actor.primaryLabel,
                  style: const TextStyle(
                    color: TaqaUiColors.charcoal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz,
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                ),
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
            style: const TextStyle(
              color: TaqaUiColors.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if ((item.event.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.event.subtitle!,
              style: TextStyle(
                color: TaqaUiColors.charcoal.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.favorite_border,
                color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${item.likeCount}',
                style: TextStyle(
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 18),
              InkWell(
                onTap: onCommentsTap,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      color: item.canComment
                          ? TaqaUiColors.charcoal.withValues(alpha: 0.54)
                          : TaqaUiColors.charcoal.withValues(alpha: 0.24),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.commentCount}',
                      style: TextStyle(
                        color: item.canComment
                            ? TaqaUiColors.charcoal.withValues(alpha: 0.7)
                            : TaqaUiColors.charcoal.withValues(alpha: 0.24),
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

/// A [TaqaRangeTab]-styled split button: tapping the label switches the
/// feed to [label]'s group, tapping the list icon opens a picker to change
/// which group this slot is bound to.
class _GroupPickerTab extends StatelessWidget {
  const _GroupPickerTab({
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onPick,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final borderColor = TaqaUiColors.charcoal.withValues(alpha: 0.12);
    return Material(
      color: selected ? TaqaUiColors.lime : TaqaUiColors.white,
      borderRadius: TaqaUiScale.radius(5),
      child: Container(
        height: TaqaUiScale.h(45),
        decoration: BoxDecoration(
          borderRadius: TaqaUiScale.radius(5),
          border: selected ? null : Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onSelect,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: TaqaUiScale.w(4)),
                    child: Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaqaUiStyles.dailyOutlookButton,
                    ),
                  ),
                ),
              ),
            ),
            Container(width: 1, height: TaqaUiScale.h(24), color: borderColor),
            InkWell(
              onTap: onPick,
              child: SizedBox(
                width: TaqaUiScale.w(36),
                child: Icon(
                  Icons.list_rounded,
                  size: TaqaUiScale.w(18),
                  color: TaqaUiColors.charcoal,
                ),
              ),
            ),
          ],
        ),
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
              : TaqaUiColors.charcoal.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.42)
                : TaqaUiColors.charcoal.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.accent
                : TaqaUiColors.charcoal.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
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
        color: TaqaUiColors.charcoal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.label, this.radius = 20});

  final String? url;
  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: TaqaUiColors.charcoal.withValues(alpha: 0.08),
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(
              label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                color: TaqaUiColors.charcoal,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
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
              color: TaqaUiColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionLabel != null && onTap != null)
          TextButton(onPressed: onTap, child: Text(actionLabel!)),
      ],
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _CommunityLoadingCard extends StatelessWidget {
  const _CommunityLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _LightCard(
      child: Column(
        children: [
          const SizedBox(height: 8),
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Loading community...',
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
            ),
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
    return _LightCard(
      child: Column(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 32,
            color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: TaqaUiColors.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.68),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class CommunityLeaderboardPage extends StatefulWidget {
  const CommunityLeaderboardPage({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.initialSummary,
  });

  final int groupId;
  final bool isAdmin;
  final CommunityLeaderboard initialSummary;

  @override
  State<CommunityLeaderboardPage> createState() =>
      _CommunityLeaderboardPageState();
}

class _CommunityLeaderboardPageState extends State<CommunityLeaderboardPage> {
  late CommunityLeaderboard _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
  }

  Future<void> _refresh() async {
    try {
      final detail = await CommunityService.fetchGroupDetail(widget.groupId);
      if (!mounted) return;
      setState(() => _summary = detail.leaderboardSummary);
    } catch (_) {}
  }

  Future<void> _changeMetric() async {
    final metric = await _showMetricPicker(context, _summary.metric);
    if (metric == null) return;
    try {
      await CommunityService.updateLeaderboardMetric(widget.groupId, metric);
      if (!mounted) return;
      AppToast.show(
        context,
        'Leaderboard metric updated.',
        type: AppToastType.success,
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: const Text('Leaderboard'),
        actions: [
          if (widget.isAdmin)
            TextButton(
              onPressed: _changeMetric,
              child: const Text('Change metric'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Metric: ${_summary.metric.replaceAll('_', ' ')}',
              style: TextStyle(
                color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            if (_summary.items.isEmpty)
              const _CommunityEmptyCard(
                title: 'No leaderboard data yet',
                message: 'Rankings will appear here once activity is recorded.',
              )
            else
              _LightCard(
                child: Column(
                  children: _summary.items
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '#${entry.rankPosition}',
                                  style: TextStyle(
                                    color: entry.isCurrentUser
                                        ? AppColors.accent
                                        : TaqaUiColors.charcoal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.displayName,
                                  style: const TextStyle(
                                    color: TaqaUiColors.charcoal,
                                  ),
                                ),
                              ),
                              Text(
                                entry.scoreLabel,
                                style: TextStyle(
                                  color: TaqaUiColors.charcoal.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityPinnedItemsPage extends StatefulWidget {
  const CommunityPinnedItemsPage({
    super.key,
    required this.groupId,
    required this.isAdmin,
    required this.initialPins,
  });

  final int groupId;
  final bool isAdmin;
  final List<CommunityPin> initialPins;

  @override
  State<CommunityPinnedItemsPage> createState() =>
      _CommunityPinnedItemsPageState();
}

class _CommunityPinnedItemsPageState extends State<CommunityPinnedItemsPage> {
  late List<CommunityPin> _pins;

  @override
  void initState() {
    super.initState();
    _pins = widget.initialPins;
  }

  Future<void> _refresh() async {
    try {
      final detail = await CommunityService.fetchGroupDetail(widget.groupId);
      if (!mounted) return;
      setState(() => _pins = detail.pinnedItems);
    } catch (_) {}
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
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  Future<void> _deletePin(CommunityPin pin) async {
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Delete pin',
      message: 'This will remove the pinned item from the group.',
      confirmLabel: 'Delete',
    );
    if (!confirm) return;
    try {
      await CommunityService.deletePin(widget.groupId, pin.pinId);
      if (!mounted) return;
      AppToast.show(context, 'Pin deleted.', type: AppToastType.success);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: const Text('Pinned Items'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              onPressed: () => _createOrEditPin(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: SafeArea(
        child: _pins.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: _CommunityEmptyCard(
                  title: 'No pins yet',
                  message:
                      'Pinned announcements and resources will appear here.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _pins.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pin = _pins[index];
                  return _PinCard(
                    pin: pin,
                    isAdmin: widget.isAdmin,
                    onEdit: () => _createOrEditPin(pin),
                    onDelete: () => _deletePin(pin),
                  );
                },
              ),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pin,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final CommunityPin pin;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MiniChip(label: pin.pinType.replaceAll('_', ' ')),
              const Spacer(),
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: TaqaUiColors.charcoal.withValues(alpha: 0.7),
                  ),
                  color: const Color(0xFF141414),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
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
              color: TaqaUiColors.charcoal,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pin.body,
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.74),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class CommunitySharedMetricsPage extends StatefulWidget {
  const CommunitySharedMetricsPage({
    super.key,
    required this.initialSettings,
    required this.onToggle,
  });

  final CommunityShareSettings initialSettings;
  final Future<void> Function(
    CommunityShareSettings Function(CommunityShareSettings settings)
    nextSettings,
  )
  onToggle;

  @override
  State<CommunitySharedMetricsPage> createState() =>
      _CommunitySharedMetricsPageState();
}

class _CommunitySharedMetricsPageState
    extends State<CommunitySharedMetricsPage> {
  late CommunityShareSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  Future<void> _toggle(
    CommunityShareSettings Function(CommunityShareSettings settings)
    nextSettings,
  ) async {
    setState(() => _settings = nextSettings(_settings));
    await widget.onToggle(nextSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBackground,
        elevation: 0,
        foregroundColor: TaqaUiColors.charcoal,
        title: const Text('Shared Metrics'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TaqaMuteNotificationsCard(
              title: 'Training Progress',
              description: 'Share your training progress with this group.',
              value: _settings.shareTrainingProgress,
              onChanged: (value) => _toggle(
                (settings) => settings.copyWith(shareTrainingProgress: value),
              ),
            ),
            const SizedBox(height: 15),
            TaqaMuteNotificationsCard(
              title: 'TAQA Fitness Score',
              description: 'Share your TAQA Fitness Score with this group.',
              value: _settings.shareTaqaScore,
              onChanged: (value) => _toggle(
                (settings) => settings.copyWith(shareTaqaScore: value),
              ),
            ),
            const SizedBox(height: 15),
            TaqaMuteNotificationsCard(
              title: 'Daily Movement',
              description: 'Share your daily movement with this group.',
              value: _settings.shareDailyMovement,
              onChanged: (value) => _toggle(
                (settings) => settings.copyWith(shareDailyMovement: value),
              ),
            ),
            const SizedBox(height: 15),
            TaqaMuteNotificationsCard(
              title: 'Wearable Data',
              description: 'Share your wearable data with this group.',
              value: _settings.shareWearableData,
              onChanged: (value) => _toggle(
                (settings) => settings.copyWith(shareWearableData: value),
              ),
            ),
            const SizedBox(height: 15),
            TaqaMuteNotificationsCard(
              title: 'Wellness',
              description: 'Share your wellness data with this group.',
              value: _settings.shareWellness,
              onChanged: (value) => _toggle(
                (settings) => settings.copyWith(shareWellness: value),
              ),
            ),
          ],
        ),
      ),
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

Future<_CreateGroupPayload?> _showCreateGroupDialog(
  BuildContext context,
) async {
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
            title: const Text(
              'Create community',
              style: TextStyle(color: Colors.white),
            ),
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
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
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
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General'),
                      ),
                      DropdownMenuItem(value: 'gym', child: Text('Gym')),
                      DropdownMenuItem(value: 'coach', child: Text('Coach')),
                      DropdownMenuItem(value: 'city', child: Text('City')),
                      DropdownMenuItem(
                        value: 'country',
                        child: Text('Country'),
                      ),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
                      isDiscoverable: visibility == 'public'
                          ? discoverable
                          : false,
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
  final descriptionController = TextEditingController(
    text: detail.description ?? '',
  );
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
            title: const Text(
              'Edit group',
              style: TextStyle(color: Colors.white),
            ),
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
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
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
                      DropdownMenuItem(
                        value: 'general',
                        child: Text('General'),
                      ),
                      DropdownMenuItem(value: 'gym', child: Text('Gym')),
                      DropdownMenuItem(value: 'coach', child: Text('Coach')),
                      DropdownMenuItem(value: 'city', child: Text('City')),
                      DropdownMenuItem(
                        value: 'country',
                        child: Text('Country'),
                      ),
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
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
                      isDiscoverable: visibility == 'public'
                          ? discoverable
                          : false,
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
            title: const Text(
              'Report content',
              style: TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: reason,
                    dropdownColor: AppColors.cardDark,
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem(
                        value: 'harassment',
                        child: Text('Harassment'),
                      ),
                      DropdownMenuItem(value: 'spam', child: Text('Spam')),
                      DropdownMenuItem(
                        value: 'contact_info',
                        child: Text('Contact info'),
                      ),
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
                onPressed: () => Navigator.pop(context, {
                  'reason': reason,
                  'details': detailsController.text.trim().isEmpty
                      ? null
                      : detailsController.text.trim(),
                }),
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

Future<int?> _showGroupPicker(
  BuildContext context,
  List<CommunityGroupSummary> groups,
  int current,
) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF111111),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Choose a group',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...groups.map(
            (group) => ListTile(
              title: Text(
                group.name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: group.id == current
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(context, group.id),
            ),
          ),
        ],
      ),
    ),
  );
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
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
                      DropdownMenuItem(
                        value: 'expert_tip',
                        child: Text('Expert tip'),
                      ),
                      DropdownMenuItem(
                        value: 'challenge_rule',
                        child: Text('Challenge rule'),
                      ),
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
                    decoration: const InputDecoration(
                      hintText: 'Pinned content',
                    ),
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
                      sortOrder:
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
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
  final descriptionController = TextEditingController(
    text: existing?.description ?? '',
  );
  final goalController = TextEditingController(
    text: existing?.goalValue?.toStringAsFixed(0) ?? '',
  );
  final unitController = TextEditingController(
    text: existing?.progressUnit ?? '',
  );
  String type = existing?.challengeType ?? 'workout_days';
  bool isActive = existing?.isActive ?? true;
  DateTime startDate = existing?.startAt ?? DateTime.now();
  DateTime endDate =
      existing?.endAt ?? DateTime.now().add(const Duration(days: 30));
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
                    decoration: const InputDecoration(
                      hintText: 'Challenge name',
                    ),
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
                      DropdownMenuItem(
                        value: 'workout_days',
                        child: Text('Workout days'),
                      ),
                      DropdownMenuItem(
                        value: 'movement_total',
                        child: Text('Movement total'),
                      ),
                      DropdownMenuItem(
                        value: 'cardio_sessions',
                        child: Text('Cardio sessions'),
                      ),
                      DropdownMenuItem(
                        value: 'score_threshold_days',
                        child: Text('Score threshold days'),
                      ),
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
                          child: Text(
                            'Start ${DateFormat('MMM d').format(startDate)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: pickEnd,
                          child: Text(
                            'End ${DateFormat('MMM d').format(endDate)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Goal value'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Progress unit',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
