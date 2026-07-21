import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/account_storage.dart';
import '../../core/user_friendly_error.dart';
import '../../services/community/community_models.dart';
import '../../services/community/community_service.dart';
import '../../theme/app_theme.dart';
import '../../TaqaUI/components/taqa_toast.dart';
import '../../TaqaUI/components/taqa_refresh_indicator.dart';
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
import '../../TaqaUI/components/taqa_community_group_picker_sheet.dart';
import '../../TaqaUI/components/taqa_community_loading_card.dart';
import '../../TaqaUI/components/taqa_community_management_list.dart';
import '../../TaqaUI/components/taqa_community_member_card.dart';
import '../../TaqaUI/components/taqa_community_option_picker_sheet.dart';
import '../../TaqaUI/components/taqa_community_report_card.dart';
import '../../TaqaUI/components/taqa_empty_card.dart';
import '../../TaqaUI/components/taqa_outline_tag_button.dart';
import '../../TaqaUI/components/taqa_page_app_bar.dart';
import '../../TaqaUI/components/taqa_page_header.dart';
import '../../TaqaUI/components/taqa_search_field.dart';
import '../../TaqaUI/components/taqa_switch.dart';
import '../../TaqaUI/Typography/taqa_ui_typography.dart';
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
  String? _cachedCommunityName;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _selectedGroupId;
  int? _pickedGroupId;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCachedCommunityName());
    _loadInitial();
  }

  Future<void> _loadCachedCommunityName() async {
    final cachedName = await AccountStorage.getName();
    if (!mounted) return;
    final trimmed = cachedName?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    setState(() => _cachedCommunityName = trimmed);
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
        final latestName = bootstrap.currentUser.primaryLabel.trim();
        if (latestName.isNotEmpty) {
          _cachedCommunityName = latestName;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(e);
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
        final latestName = bootstrap.currentUser.primaryLabel.trim();
        if (latestName.isNotEmpty) {
          _cachedCommunityName = latestName;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(e);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: TaqaUiScale.h(60)),
            child: TaqaRefreshIndicator(
              onRefresh: _refreshFeed,
              child: ListView(
                padding: TaqaUiScale.insetsLTRB(20, 0, 20, 32),
                children: [
                  _buildHeroCard(),
                  SizedBox(height: TaqaUiScale.h(18)),
                  _buildQuickActions(),
                  SizedBox(height: TaqaUiScale.h(18)),
                  if (_bootstrap != null) ...[
                    _buildJoinedGroupsSection(),
                    SizedBox(height: TaqaUiScale.h(18)),
                    _buildChallengePreview(),
                    SizedBox(height: TaqaUiScale.h(18)),
                  ],
                  _buildFeedFilterBar(),
                  SizedBox(height: TaqaUiScale.h(14)),
                  if (_loading)
                    const TaqaCommunityLoadingCard()
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
          ),
          Positioned(
            top: TaqaUiScale.h(12),
            left: TaqaUiScale.w(16),
            child: const TaqaPageHeader(title: 'Community'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final bootstrap = _bootstrap;
    final resolvedName =
        bootstrap?.currentUser.primaryLabel.trim().isNotEmpty == true
        ? bootstrap!.currentUser.primaryLabel.trim()
        : (_cachedCommunityName?.trim().isNotEmpty == true
              ? _cachedCommunityName!.trim()
              : 'Athlete');
    return TaqaCommunityHeroCard(
      welcomeText: 'Welcome back, $resolvedName',
      greetingText: 'Welcome back,',
      userNameText: resolvedName,
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
  String? _error;
  final Set<String> _selectedKinds = {};

  static const List<String> _groupKindOptions = [
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

  /// Groups discoverable by more than one kind at a time. The backend only
  /// filters by a single `group_kind`, so with 0 or 1 kind selected we let
  /// it filter; with several selected we fetch unfiltered and narrow down
  /// client-side to the chosen mix.
  List<CommunityGroupSummary> _applyKindFilter(
    List<CommunityGroupSummary> items,
  ) {
    if (_selectedKinds.length <= 1) return items;
    return items
        .where((group) => _selectedKinds.contains(group.groupKind))
        .toList(growable: false);
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
        groupKind: _selectedKinds.length == 1 ? _selectedKinds.first : null,
      );
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(_applyKindFilter(page.items));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(e);
        _loading = false;
      });
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
      appBar: const TaqaPageAppBar(
        title: 'Discover Communities',
        backgroundColor: AppColors.appBackground,
      ),
      body: SafeArea(
        top: false,
        child: TaqaRefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              TaqaUiScale.w(16),
              TaqaUiScale.h(8),
              TaqaUiScale.w(16),
              TaqaUiScale.h(20),
            ),
            children: [
              TaqaSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(),
              ),
              SizedBox(height: TaqaUiScale.h(15)),
              TaqaCommunityFilterGrid(
                labels: const [
                  'General',
                  'Gym',
                  'Coach',
                  'City',
                  'Country',
                  'Sport',
                ],
                selectedIndexes: {
                  for (var i = 0; i < _groupKindOptions.length; i++)
                    if (_selectedKinds.contains(_groupKindOptions[i])) i,
                },
                onToggle: (index) async {
                  final kind = _groupKindOptions[index];
                  setState(() {
                    if (!_selectedKinds.remove(kind)) {
                      _selectedKinds.add(kind);
                    }
                  });
                  await _load();
                },
              ),
              SizedBox(height: TaqaUiScale.h(16)),
              if (_loading)
                const TaqaCommunityLoadingCard(label: 'Loading communities...')
              else if (_error != null) ...[
                TaqaEmptyCard(
                  title: 'Could not load public groups',
                  subtitle: _error,
                ),
                SizedBox(height: TaqaUiScale.h(12)),
                OutlinedButton(
                  onPressed: () => _load(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TaqaUiColors.charcoal,
                    side: BorderSide(
                      color: TaqaUiColors.charcoal.withValues(alpha: 0.18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Retry'),
                ),
              ] else if (_groups.isEmpty)
                const TaqaEmptyCard(
                  title: 'No public groups found',
                  subtitle: 'Try a broader search or create your own community',
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
                          ? TaqaOutlineTagButton(
                              label: 'Joined',
                              width: TaqaUiStyles.communitySectionTagWidth,
                            )
                          : null,
                      onTap: () => _openGroup(group),
                    ),
                  ),
                ),
            ],
          ),
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
        _error = userFriendlyErrorMessage(e);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  Future<void> _resetCode() async {
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Reset join code',
      message: 'Anyone using the old 6-digit code will lose access to join.',
      confirmLabel: 'Reset',
    );
    if (!confirm) return;
    try {
      final newCode = await CommunityService.regenerateJoinCode(widget.groupId);
      if (!mounted) return;
      await _showGroupCodeDialog(
        context,
        title: 'New group code',
        code: newCode,
        message:
            'The previous invite code no longer works. Share this new code with members you want to invite.',
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final scaffold = Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: detail?.name ?? 'Community',
        trailing: detail?.isAdmin == true
            ? IconButton(
                tooltip: 'Group management',
                icon: Icon(
                  Icons.settings_outlined,
                  size: TaqaUiScale.w(22),
                  color: TaqaUiColors.charcoal,
                ),
                onPressed: () async {
                  final action = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CommunityGroupManagementPage(groupName: detail!.name),
                    ),
                  );
                  if (!mounted || action == null) return;
                  if (action == 'edit') await _editGroup();
                  if (action == 'view_code') await _viewCode();
                  if (action == 'code') await _resetCode();
                  if (action == 'members') await _openMembers();
                  if (action == 'metric') await _changeLeaderboardMetric();
                  if (action == 'challenges') await _openGroupChallenges();
                  if (action == 'pin') await _openPinnedItems();
                  if (action == 'reports') await _openGroupReports();
                  if (action == 'archive') await _archiveGroup();
                },
              )
            : null,
      ),
      body: TaqaRefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: TaqaUiScale.symmetric(horizontal: 20, vertical: 20),
          children: [
            if (_loading)
              const TaqaCommunityLoadingCard()
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Archive group',
      message:
          'This will archive the group and remove it from normal community use.',
      confirmLabel: 'Archive',
    );
    if (!confirm) return;
    try {
      await CommunityService.archiveGroup(detail.id);
      if (!mounted) return;
      AppToast.show(context, 'Group archived.', type: AppToastType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      appBar: const TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: 'Your Groups',
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

/// TaqaUI home for all group-admin tools.  Keeping these actions on a page
/// instead of a platform popup makes the management flow match Community's
/// scaled cards and gives every action a clear description.
class CommunityGroupManagementPage extends StatelessWidget {
  const CommunityGroupManagementPage({super.key, required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: const TaqaPageAppBar(
        title: 'Group Management',
        backgroundColor: AppColors.appBackground,
      ),
      body: SafeArea(
        top: false,
        child: TaqaCommunityManagementList(
          groupName: groupName,
          onActionTap: (action) => Navigator.pop(context, action),
        ),
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
        _error = userFriendlyErrorMessage(e);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  Future<void> _openChallengeActions(CommunityChallenge challenge) async {
    final canManage = _canManageChallenge(challenge);
    final action = await showTaqaOptionDialog<String>(
      context: context,
      title: challenge.name,
      options: [
        TaqaDialogOption(
          value: 'mute',
          title: challenge.mutedNotifications
              ? 'Unmute notifications'
              : 'Mute notifications',
        ),
        if (canManage)
          const TaqaDialogOption(value: 'edit', title: 'Edit challenge'),
        if (canManage)
          const TaqaDialogOption(value: 'delete', title: 'Delete challenge'),
      ],
    );
    if (action == null) return;
    if (action == 'mute') {
      await _toggleMute(challenge, !challenge.mutedNotifications);
    } else if (action == 'edit') {
      await _editChallenge(challenge);
    } else if (action == 'delete') {
      await _deleteChallenge(challenge);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: widget.title,
        trailing: _canCreateForCurrentTab
            ? IconButton(
                onPressed: _createChallenge,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: TaqaUiColors.unnamedColor1c1d17,
                ),
              )
            : null,
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
      body: TaqaRefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loading)
              const TaqaCommunityLoadingCard()
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
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(15)),
                  child: TaqaCommunityChallengeCard(
                    tag: challenge.challengeType.replaceAll('_', ' '),
                    name: challenge.name,
                    progress: challenge.progressPercent / 100,
                    onTap: () => _openChallengeActions(challenge),
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
        _error = userFriendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _showEarnedOnly ? _earnedBadges : _allBadges;
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: const TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: 'Badges',
      ),
      body: TaqaRefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: TaqaRangeTab(
                    label: 'All badges',
                    selected: !_showEarnedOnly,
                    onTap: () => setState(() => _showEarnedOnly = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TaqaRangeTab(
                    label: 'Earned badges',
                    selected: _showEarnedOnly,
                    onTap: () => setState(() => _showEarnedOnly = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const TaqaCommunityLoadingCard()
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
                  child: _CommunityBadgeCard(badge: badge),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityBadgeCard extends StatelessWidget {
  const _CommunityBadgeCard({required this.badge});

  final CommunityBadge badge;

  @override
  Widget build(BuildContext context) {
    final tagWidth = ((badge.category.length * 7) + 10)
        .clamp(34, 112)
        .toDouble();
    return Container(
      width: TaqaUiStyles.communityChallengeCardWidth,
      constraints: BoxConstraints(minHeight: TaqaUiScale.h(98)),
      padding: EdgeInsets.fromLTRB(
        TaqaUiScale.w(14),
        TaqaUiScale.h(14),
        TaqaUiScale.w(14),
        TaqaUiScale.h(14),
      ),
      decoration: BoxDecoration(
        color: badge.isEarned
            ? TaqaUiColors.unnamedColorE4e93b
            : TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: TaqaUiScale.h(2)),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: TaqaUiScale.w(21),
              color: TaqaUiColors.unnamedColor1c1d17,
            ),
          ),
          SizedBox(width: TaqaUiScale.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: TaqaUiScale.h(2)),
                        child: Text(
                          badge.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(15),
                            fontWeight: FontWeight.w700,
                            height: 21 / 15,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: TaqaUiScale.w(8)),
                    TaqaOutlineTagButton(
                      label: badge.category,
                      width: TaqaUiScale.w(tagWidth),
                    ),
                  ],
                ),
                SizedBox(height: TaqaUiScale.h(10)),
                Text(
                  badge.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(15),
                    fontWeight: FontWeight.w400,
                    height: 21 / 15,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final Set<String> _selectedStatuses = <String>{};

  static const List<String> _statusOptions = [
    'open',
    'reviewing',
    'resolved',
    'dismissed',
  ];

  List<CommunityReport> get _visibleReports => _selectedStatuses.isEmpty
      ? _reports
      : _reports
            .where((report) => _selectedStatuses.contains(report.status))
            .toList(growable: false);

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
          ? await CommunityService.fetchAdminReports()
          : await CommunityService.fetchGroupReports(widget.groupId!);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFriendlyErrorMessage(e);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: widget.title,
      ),
      body: TaqaRefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: TaqaUiScale.insetsLTRB(16, 8, 16, 24),
          children: [
            TaqaCommunityFilterGrid(
              labels: const ['Open', 'Reviewing', 'Resolved', 'Dismissed'],
              selectedIndexes: {
                for (var index = 0; index < _statusOptions.length; index++)
                  if (_selectedStatuses.contains(_statusOptions[index])) index,
              },
              onToggle: (index) {
                setState(() {
                  final status = _statusOptions[index];
                  if (!_selectedStatuses.remove(status)) {
                    _selectedStatuses.add(status);
                  }
                });
              },
            ),
            SizedBox(height: TaqaUiScale.h(16)),
            if (_loading)
              const TaqaCommunityLoadingCard()
            else if (_error != null)
              _CommunityEmptyCard(
                title: 'Could not load moderation queue',
                message: _error!,
                actionLabel: 'Retry',
                onPressed: () => _load(),
              )
            else if (_visibleReports.isEmpty)
              _CommunityEmptyCard(
                title: _selectedStatuses.isEmpty
                    ? 'No reports'
                    : 'No matching reports',
                message: _selectedStatuses.isEmpty
                    ? 'The moderation queue is currently clear.'
                    : 'Try a different combination of report statuses.',
              )
            else
              ..._visibleReports.map(
                (report) => Padding(
                  padding: EdgeInsets.only(bottom: TaqaUiScale.h(12)),
                  child: TaqaCommunityReportCard(
                    status: report.status,
                    targetType: report.targetType,
                    reason: report.reason,
                    targetId: report.targetId,
                    details: report.details,
                    actions: [
                      TaqaCommunityReportAction(
                        label: 'Review',
                        onTap: () => _review(report, 'reviewing'),
                      ),
                      TaqaCommunityReportAction(
                        label: 'Dismiss',
                        onTap: () => _review(report, 'dismissed'),
                      ),
                      TaqaCommunityReportAction(
                        label: 'Resolve',
                        isPrimary: true,
                        onTap: () => _review(report, 'resolved'),
                      ),
                      if (report.targetType == 'feed_item')
                        TaqaCommunityReportAction(
                          label: 'Hide item',
                          onTap: () => _moderate(report, 'hidden'),
                        ),
                      if (report.targetType == 'comment')
                        TaqaCommunityReportAction(
                          label: 'Block comment',
                          onTap: () => _moderate(report, 'blocked'),
                        ),
                      if (report.targetType == 'comment')
                        TaqaCommunityReportAction(
                          label: 'Delete comment',
                          onTap: () => _moderate(report, 'deleted'),
                        ),
                    ],
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
        _error = userFriendlyErrorMessage(e);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
        _error = userFriendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _remove(CommunityMembership member) async {
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Remove member',
      message: 'This will remove ${member.displayName} from the group.',
      confirmLabel: 'Remove',
    );
    if (!confirm) return;
    try {
      await CommunityService.removeGroupMember(widget.groupId, member.userId);
      if (!mounted) return;
      AppToast.show(context, 'Member removed.', type: AppToastType.success);
      await _load();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  Future<void> _setRole(CommunityMembership member, String role) async {
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: role == 'admin' ? 'Make admin' : 'Make member',
      message: role == 'admin'
          ? 'Give ${member.displayName} admin access for this community.'
          : 'Remove admin access from ${member.displayName}.',
      confirmLabel: role == 'admin' ? 'Promote' : 'Demote',
    );
    if (!confirm) return;
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  Future<void> _transferAdmin(CommunityMembership member) async {
    final confirm = await showTaqaConfirmDialog(
      context: context,
      title: 'Transfer ownership',
      message: 'Make ${member.displayName} the new group admin.',
      confirmLabel: 'Transfer',
    );
    if (!confirm) return;
    try {
      await CommunityService.transferAdmin(widget.groupId, member.userId);
      if (!mounted) return;
      AppToast.show(context, 'Admin transferred.', type: AppToastType.success);
      await _load();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
          decoration: BoxDecoration(
            color: TaqaUiColors.unnamedColorE3e3e3,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(TaqaUiScale.r(24)),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: TaqaUiScale.h(12)),
              Container(
                width: TaqaUiScale.w(44),
                height: TaqaUiScale.h(5),
                decoration: BoxDecoration(
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.2),
                  borderRadius: TaqaUiScale.radius(999),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(14)),
              Text(
                widget.groupName,
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.interTight,
                  color: TaqaUiColors.charcoal,
                  fontSize: TaqaUiScale.sp(18),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: TaqaUiScale.h(4)),
              Text(
                'MEMBERS',
                style: TextStyle(
                  fontFamily: TaqaUiFontFamilies.iaWriterMonoS,
                  fontSize: TaqaUiScale.sp(8),
                  color: TaqaUiColors.charcoal.withValues(alpha: 0.55),
                ),
              ),
              SizedBox(height: TaqaUiScale.h(12)),
              Expanded(
                child: _loading
                    ? Center(
                        child: SizedBox(
                          width: TaqaUiScale.w(28),
                          height: TaqaUiScale.h(28),
                          child: CircularProgressIndicator(
                            strokeWidth: TaqaUiScale.w(2),
                            color: TaqaUiColors.charcoal,
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: TaqaUiScale.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: TaqaUiColors.charcoal.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: TaqaUiScale.insetsLTRB(16, 0, 16, 24),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          return Padding(
                            padding: EdgeInsets.only(bottom: TaqaUiScale.h(10)),
                            child: TaqaCommunityMemberCard(
                              name: member.displayName,
                              role: member.role,
                              status: member.status,
                              avatarUrl: member.avatarUrl,
                              actions:
                                  widget.canAdminManage &&
                                      member.status == 'active'
                                  ? [
                                      if (member.role != 'admin')
                                        const TaqaCommunityMemberAction(
                                          id: 'promote',
                                          label: 'Make admin',
                                        ),
                                      if (member.role == 'admin')
                                        const TaqaCommunityMemberAction(
                                          id: 'demote',
                                          label: 'Make member',
                                        ),
                                      const TaqaCommunityMemberAction(
                                        id: 'transfer',
                                        label: 'Transfer admin',
                                      ),
                                      const TaqaCommunityMemberAction(
                                        id: 'remove',
                                        label: 'Remove',
                                      ),
                                    ]
                                  : const [],
                              onActionTap: (action) async {
                                if (action == 'promote') {
                                  await _setRole(member, 'admin');
                                } else if (action == 'demote') {
                                  await _setRole(member, 'member');
                                } else if (action == 'transfer') {
                                  await _transferAdmin(member);
                                } else if (action == 'remove') {
                                  await _remove(member);
                                }
                              },
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
      padding: TaqaUiScale.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(18),
        border: Border.all(
          color: TaqaUiColors.charcoal.withValues(alpha: 0.08),
        ),
      ),
      child: child,
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
            size: TaqaUiScale.w(32),
            color: TaqaUiColors.charcoal.withValues(alpha: 0.54),
          ),
          SizedBox(height: TaqaUiScale.h(12)),
          Text(
            title,
            style: TextStyle(
              color: TaqaUiColors.charcoal,
              fontFamily: TaqaUiFontFamilies.interTight,
              fontSize: TaqaUiScale.sp(16),
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: TaqaUiScale.h(8)),
          Text(
            message,
            style: TextStyle(
              color: TaqaUiColors.charcoal.withValues(alpha: 0.68),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onPressed != null) ...[
            SizedBox(height: TaqaUiScale.h(14)),
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: 'Leaderboard',
        trailing: widget.isAdmin
            ? TextButton(
                onPressed: _changeMetric,
                child: const Text('Change metric'),
              )
            : null,
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
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
      AppToast.show(context, userFriendlyErrorMessage(e), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: 'Pinned Items',
        trailing: widget.isAdmin
            ? IconButton(
                onPressed: () => _createOrEditPin(),
                icon: const Icon(Icons.add),
              )
            : null,
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
      appBar: const TaqaPageAppBar(
        backgroundColor: AppColors.appBackground,
        title: 'Shared Metrics',
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
  final result = await showTaqaTextValueDialog(
    context: context,
    title: 'Join by code',
    initialValue: '',
    keyboardType: TextInputType.number,
    confirmLabel: 'Join',
    hintText: '6-Digit Code',
    maxLength: 6,
  );
  final trimmed = result?.trim();
  if (trimmed == null || trimmed.length != 6) return null;
  return trimmed;
}

Future<void> _showGroupCodeDialog(
  BuildContext context, {
  required String title,
  required String code,
  String? message,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: TaqaUiScale.symmetric(horizontal: 17),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.none,
            child: Container(
              constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
              padding: TaqaUiScale.insetsLTRB(17, 15, 17, 15),
              decoration: BoxDecoration(
                color: TaqaUiColors.white,
                borderRadius: TaqaUiScale.radius(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(15),
                      fontWeight: FontWeight.w700,
                      height: 25 / 15,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  if (message != null && message.trim().isNotEmpty) ...[
                    SizedBox(height: TaqaUiScale.h(12)),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: TaqaUiFontFamilies.interTight,
                        fontSize: TaqaUiScale.sp(13),
                        fontWeight: FontWeight.w400,
                        height: 18 / 13,
                        letterSpacing: 0,
                        color: TaqaUiColors.unnamedColor1c1d17.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: TaqaUiScale.h(24)),
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(32),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  Material(
                    color: TaqaUiColors.unnamedColorE4e93b,
                    borderRadius: TaqaUiScale.radius(5),
                    child: InkWell(
                      borderRadius: TaqaUiScale.radius(5),
                      onTap: () => Navigator.pop(ctx),
                      child: SizedBox(
                        width: double.infinity,
                        height: TaqaUiScale.h(45),
                        child: Center(
                          child: Text(
                            "CLOSE",
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(10),
                              fontWeight: FontWeight.w700,
                              height: 12 / 10,
                              letterSpacing: 0,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _taqaDialogField({
  required TextEditingController controller,
  required String hint,
  int maxLines = 1,
  String? errorText,
}) {
  return Container(
    width: double.infinity,
    padding: TaqaUiScale.insetsLTRB(0, 8, 0, 8),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: TaqaUiColors.unnamedColorE3e3e3),
      ),
    ),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: TaqaUiFontFamilies.interTight,
        fontSize: TaqaUiScale.sp(16),
        fontWeight: FontWeight.w500,
        color: TaqaUiColors.unnamedColor1c1d17,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintText: hint,
        errorText: errorText,
        errorStyle: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(12),
          fontWeight: FontWeight.w400,
          color: TaqaUiColors.unnamedColorE93b3b,
        ),
        hintStyle: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(16),
          fontWeight: FontWeight.w400,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.3),
        ),
      ),
    ),
  );
}

Widget _taqaDialogDropdown<T>({
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Container(
    width: double.infinity,
    padding: TaqaUiScale.insetsLTRB(0, 4, 0, 4),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: TaqaUiColors.unnamedColorE3e3e3),
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: TaqaUiColors.white,
        borderRadius: TaqaUiScale.radius(12),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
        ),
        items: items,
        style: TextStyle(
          fontFamily: TaqaUiFontFamilies.interTight,
          fontSize: TaqaUiScale.sp(16),
          fontWeight: FontWeight.w500,
          color: TaqaUiColors.unnamedColor1c1d17,
        ),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _taqaDialogDateField({
  required String label,
  required String value,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: double.infinity,
      padding: TaqaUiScale.insetsLTRB(0, 8, 0, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TaqaUiColors.unnamedColorE3e3e3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(11),
                    fontWeight: FontWeight.w400,
                    color: TaqaUiColors.unnamedColor1c1d17.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                SizedBox(height: TaqaUiScale.h(2)),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: TaqaUiFontFamilies.interTight,
                    fontSize: TaqaUiScale.sp(16),
                    fontWeight: FontWeight.w500,
                    color: TaqaUiColors.unnamedColor1c1d17,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.calendar_today_outlined,
            size: TaqaUiScale.w(16),
            color: TaqaUiColors.unnamedColor1c1d17.withValues(alpha: 0.35),
          ),
        ],
      ),
    ),
  );
}

Future<_CreateGroupPayload?> _showGroupFormDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  String initialDescription = '',
  String initialVisibility = 'private',
  String initialKind = 'general',
  bool initialDiscoverable = true,
}) async {
  final nameController = TextEditingController(text: initialName);
  final descriptionController = TextEditingController(text: initialDescription);
  String visibility = initialVisibility;
  String kind = initialKind;
  bool discoverable = initialDiscoverable;
  String? nameError;

  final result = await showDialog<_CreateGroupPayload>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      return StatefulBuilder(
        builder: (ctx, setLocalState) {
          return MediaQuery.removeViewInsets(
            context: ctx,
            removeBottom: true,
            child: TaqaPopupDialog(
              bottomInset: bottomInset,
              padding: TaqaUiScale.insetsLTRB(20, 24, 20, 20),
              maxHeightFactor: 0.84,
              onBackgroundTap: () =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: TaqaUiFontFamilies.interTight,
                      fontSize: TaqaUiScale.sp(22),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: TaqaUiColors.unnamedColor1c1d17,
                    ),
                  ),
                  SizedBox(height: TaqaUiScale.h(28)),
                  _taqaDialogField(
                    controller: nameController,
                    hint: 'Group Name',
                    errorText: nameError,
                  ),
                  SizedBox(height: TaqaUiScale.h(20)),
                  _taqaDialogField(
                    controller: descriptionController,
                    hint: 'Description',
                    maxLines: 3,
                  ),
                  SizedBox(height: TaqaUiScale.h(20)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _taqaDialogDropdown<String>(
                          value: visibility,
                          items: const [
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('Private'),
                            ),
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('Public'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => visibility = value);
                          },
                        ),
                      ),
                      SizedBox(width: TaqaUiScale.w(20)),
                      Expanded(
                        child: _taqaDialogDropdown<String>(
                          value: kind,
                          items: const [
                            DropdownMenuItem(
                              value: 'general',
                              child: Text('General'),
                            ),
                            DropdownMenuItem(value: 'gym', child: Text('Gym')),
                            DropdownMenuItem(
                              value: 'coach',
                              child: Text('Coach'),
                            ),
                            DropdownMenuItem(
                              value: 'city',
                              child: Text('City'),
                            ),
                            DropdownMenuItem(
                              value: 'country',
                              child: Text('Country'),
                            ),
                            DropdownMenuItem(
                              value: 'sport',
                              child: Text('Sport'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setLocalState(() => kind = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(24)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Discoverable',
                          style: TextStyle(
                            fontFamily: TaqaUiFontFamilies.interTight,
                            fontSize: TaqaUiScale.sp(16),
                            fontWeight: FontWeight.w500,
                            color: TaqaUiColors.unnamedColor1c1d17,
                          ),
                        ),
                      ),
                      TaqaSwitch(
                        value: visibility == 'public' ? discoverable : false,
                        onChanged: visibility == 'public'
                            ? (value) =>
                                  setLocalState(() => discoverable = value)
                            : null,
                      ),
                    ],
                  ),
                  SizedBox(height: TaqaUiScale.h(28)),
                  SizedBox(
                    height: TaqaUiScale.h(50),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Center(
                              child: Text(
                                "CANCEL",
                                style: TextStyle(
                                  fontFamily: TaqaUiFontFamilies.interTight,
                                  fontSize: TaqaUiScale.sp(13),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  color: TaqaUiColors.unnamedColor1c1d17,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: TaqaUiColors.unnamedColorE4e93b,
                          borderRadius: TaqaUiScale.radius(14),
                          child: InkWell(
                            borderRadius: TaqaUiScale.radius(14),
                            onTap: () {
                              final name = nameController.text.trim();
                              if (name.length < 3) {
                                setLocalState(() {
                                  nameError =
                                      'Group name must be at least 3 characters.';
                                });
                                return;
                              }
                              if (nameError != null) {
                                setLocalState(() => nameError = null);
                              }
                              Navigator.pop(
                                ctx,
                                _CreateGroupPayload(
                                  name: name,
                                  description:
                                      descriptionController.text.trim().isEmpty
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
                            child: SizedBox(
                              width: TaqaUiScale.w(170),
                              height: TaqaUiScale.h(50),
                              child: Center(
                                child: Text(
                                  confirmLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(13),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ),
                            ),
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
    },
  );
  nameController.dispose();
  descriptionController.dispose();
  return result;
}

Future<_CreateGroupPayload?> _showCreateGroupDialog(BuildContext context) {
  return _showGroupFormDialog(
    context,
    title: 'Create community',
    confirmLabel: 'Create',
  );
}

Future<_CreateGroupPayload?> _showEditGroupDialog(
  BuildContext context,
  CommunityGroupDetail detail,
) {
  return _showGroupFormDialog(
    context,
    title: 'Edit group',
    confirmLabel: 'Save',
    initialName: detail.name,
    initialDescription: detail.description ?? '',
    initialVisibility: detail.visibility ?? 'private',
    initialKind: detail.groupKind ?? 'general',
    initialDiscoverable: detail.isDiscoverable,
  );
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
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => TaqaCommunityGroupPickerSheet(
      selectedId: current,
      options: groups
          .map(
            (group) => TaqaCommunityGroupPickerOption(
              id: group.id,
              name: group.name,
              memberCount: group.memberCount,
              description: group.description,
            ),
          )
          .toList(growable: false),
      onSelected: (groupId) => Navigator.pop(sheetContext, groupId),
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
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => TaqaCommunityOptionPickerSheet(
      title: 'Choose leaderboard metric',
      options: metrics,
      selectedValue: current,
      onSelected: (metric) => Navigator.pop(sheetContext, metric),
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
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> pickStart() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: startDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setLocalState(() => startDate = picked);
              }
            }

            Future<void> pickEnd() async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: endDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2035),
              );
              if (picked != null) {
                setLocalState(() => endDate = picked);
              }
            }

            return Align(
              alignment: Alignment.center,
              child: Padding(
                padding: TaqaUiScale.symmetric(horizontal: 17),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.none,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: TaqaUiScale.w(356)),
                    padding: TaqaUiScale.insetsLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: TaqaUiColors.white,
                      borderRadius: TaqaUiScale.radius(24),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            existing == null
                                ? 'Create Challenge'
                                : 'Edit Challenge',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: TaqaUiFontFamilies.interTight,
                              fontSize: TaqaUiScale.sp(22),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: TaqaUiColors.unnamedColor1c1d17,
                            ),
                          ),
                          SizedBox(height: TaqaUiScale.h(28)),
                          _taqaDialogField(
                            controller: nameController,
                            hint: 'Challenge Name',
                          ),
                          SizedBox(height: TaqaUiScale.h(20)),
                          _taqaDialogField(
                            controller: descriptionController,
                            hint: 'Description',
                            maxLines: 3,
                          ),
                          SizedBox(height: TaqaUiScale.h(20)),
                          _taqaDialogDropdown<String>(
                            value: type,
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
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setLocalState(() => type = value);
                            },
                          ),
                          SizedBox(height: TaqaUiScale.h(20)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _taqaDialogDateField(
                                  label: 'Start',
                                  value: DateFormat('MMM d').format(startDate),
                                  onTap: pickStart,
                                ),
                              ),
                              SizedBox(width: TaqaUiScale.w(20)),
                              Expanded(
                                child: _taqaDialogDateField(
                                  label: 'End',
                                  value: DateFormat('MMM d').format(endDate),
                                  onTap: pickEnd,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: TaqaUiScale.h(20)),
                          _taqaDialogField(
                            controller: goalController,
                            hint: 'Goal Value',
                          ),
                          SizedBox(height: TaqaUiScale.h(20)),
                          _taqaDialogField(
                            controller: unitController,
                            hint: 'Progress Unit',
                          ),
                          SizedBox(height: TaqaUiScale.h(24)),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    fontFamily: TaqaUiFontFamilies.interTight,
                                    fontSize: TaqaUiScale.sp(16),
                                    fontWeight: FontWeight.w500,
                                    color: TaqaUiColors.unnamedColor1c1d17,
                                  ),
                                ),
                              ),
                              TaqaSwitch(
                                value: isActive,
                                onChanged: (value) =>
                                    setLocalState(() => isActive = value),
                              ),
                            ],
                          ),
                          SizedBox(height: TaqaUiScale.h(28)),
                          SizedBox(
                            height: TaqaUiScale.h(50),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(ctx),
                                    child: Center(
                                      child: Text(
                                        'CANCEL',
                                        style: TextStyle(
                                          fontFamily:
                                              TaqaUiFontFamilies.interTight,
                                          fontSize: TaqaUiScale.sp(13),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0,
                                          color:
                                              TaqaUiColors.unnamedColor1c1d17,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Material(
                                  color: TaqaUiColors.unnamedColorE4e93b,
                                  borderRadius: TaqaUiScale.radius(14),
                                  child: InkWell(
                                    borderRadius: TaqaUiScale.radius(14),
                                    onTap: () {
                                      final name = nameController.text.trim();
                                      if (name.length < 3) return;
                                      Navigator.pop(
                                        ctx,
                                        _ChallengeEditorResult(
                                          name: name,
                                          description:
                                              descriptionController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : descriptionController.text
                                                    .trim(),
                                          challengeType: type,
                                          startAtIso: _startOfDayIso(startDate),
                                          endAtIso: _endOfDayIso(endDate),
                                          goalValue: double.tryParse(
                                            goalController.text.trim(),
                                          ),
                                          progressUnit:
                                              unitController.text.trim().isEmpty
                                              ? null
                                              : unitController.text.trim(),
                                          isActive: isActive,
                                        ),
                                      );
                                    },
                                    child: SizedBox(
                                      width: TaqaUiScale.w(170),
                                      height: TaqaUiScale.h(50),
                                      child: Center(
                                        child: Text(
                                          existing == null ? 'CREATE' : 'SAVE',
                                          style: TextStyle(
                                            fontFamily:
                                                TaqaUiFontFamilies.interTight,
                                            fontSize: TaqaUiScale.sp(13),
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0,
                                            color:
                                                TaqaUiColors.unnamedColor1c1d17,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
