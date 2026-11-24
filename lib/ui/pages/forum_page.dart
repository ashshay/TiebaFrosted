import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/capsule_tab_strip.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/profile_header.dart';
import '../widgets/refresh.dart';
import '../widgets/skeleton.dart';
import '../widgets/thread_card.dart';

/// 贴吧主页：折叠头 + 关注/签到 + 帖子分区（最新 / 精品 / 吧内分区）+ 发帖/吧资料/吧规。
class ForumPage extends StatefulWidget {
  const ForumPage({
    super.key,
    required this.forumName,
    this.initialAvatar = '',
  });

  final String forumName;
  final String initialAvatar;

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  static const _latestKey = 'latest';
  static const _goodKey = 'good';
  static const _tabKeyPrefix = 'tab-';

  final ScrollController _scroll = ScrollController();
  final Map<String, _SectionState> _sections = {};

  TiebaForum _forum = const TiebaForum();
  List<ForumTab> _generalTabs = const [];
  String _tbs = '';
  String _section = _latestKey;
  bool _signing = false;
  bool _refreshing = false;
  double _swipeDx = 0;

  String get _forumName =>
      _forum.name.isNotEmpty ? _forum.name : widget.forumName;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load(key: _section, refresh: true));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 分区模型：最新（带排序菜单）/ 精品 / 吧内通用分区
  // ---------------------------------------------------------------------------

  List<CapsuleTabItem<String>> get _stripTabs => [
    CapsuleTabItem(value: _latestKey, label: '最新', onMenuTap: _pickLatestSort),
    const CapsuleTabItem(value: _goodKey, label: '精品'),
    for (final tab in _generalTabs)
      CapsuleTabItem(
        value: '$_tabKeyPrefix${tab.tabId}',
        label: tab.tabName,
        onMenuTap: tab.sortMenu.isEmpty ? null : () => _pickSectionSort(tab),
      ),
  ];

  ForumTab? _tabOf(String key) {
    if (!key.startsWith(_tabKeyPrefix)) return null;
    final tabId = int.tryParse(key.substring(_tabKeyPrefix.length));
    if (tabId == null) return null;
    for (final tab in _generalTabs) {
      if (tab.tabId == tabId) return tab;
    }
    return null;
  }

  _SectionState _stateOf(String key) {
    final existing = _sections[key];
    if (existing != null) return existing;
    final created = _SectionState(sortType: _initialSortFor(key));
    _sections[key] = created;
    return created;
  }

  int _initialSortFor(String key) {
    if (key == _latestKey) {
      return context.read<FrostedSettings>().defaultSortType.clamp(0, 1);
    }
    if (key == _goodKey) return -1;
    final menu = _tabOf(key)?.sortMenu ?? const <TiebaSortOption>[];
    return menu.isEmpty ? -1 : menu.first.sortType;
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final state = _sections[_section];
    if (state == null) return;
    if (!state.hasMore || state.loading || state.loadingMore) return;
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 360) {
      unawaited(_load(key: _section, refresh: false));
    }
  }

  // ---------------------------------------------------------------------------
  // 拉取
  // ---------------------------------------------------------------------------

  Future<void> _load({required String key, required bool refresh}) async {
    final state = _stateOf(key);
    final tab = _tabOf(key);
    final isTab = key.startsWith(_tabKeyPrefix);
    if (isTab && (tab == null || _forum.id <= 0)) return;

    if (refresh) {
      setState(() {
        state.loading = state.threads.isEmpty;
        state.error = null;
      });
    } else {
      setState(() => state.loadingMore = true);
    }

    try {
      final repo = context.read<TiebaRepo>();
      if (isTab) {
        final nextPage = refresh ? 1 : state.page + 1;
        final res = await repo.getForumTabThreads(
          forumId: _forum.id,
          tab: tab!,
          sortType: state.sortType,
          page: nextPage,
          lastThreadId: refresh ? 0 : state.lastThreadId,
        );
        if (!mounted) return;
        setState(() {
          _mergeThreads(state, res.threads, refresh: refresh);
          state.page = nextPage;
          if (res.lastThreadId > 0) state.lastThreadId = res.lastThreadId;
          state.hasMore = res.hasMore;
          state.loading = false;
          state.loadingMore = false;
          state.loaded = true;
        });
        return;
      }

      final sortType = key == _goodKey ? -1 : state.sortType;
      // 置顶帖与部分楼层不在 thread_list 里，只给 id，按 30 个一批补齐。
      if (!refresh && state.pending.isNotEmpty) {
        final batch = state.pending.take(30).toList();
        state.pending.removeRange(0, math.min(30, state.pending.length));
        final more = await repo.getForumThreadsByIds(
          forumId: _forum.id,
          forumName: _forumName,
          threadIds: batch,
          page: state.page,
          sortType: sortType,
        );
        if (!mounted) return;
        setState(() {
          _mergeThreads(state, more, refresh: false);
          state.loadingMore = false;
          state.loaded = true;
        });
        return;
      }

      final nextPage = refresh ? 1 : state.page + 1;
      final res = await repo.getForumPage(
        forumName: widget.forumName,
        page: nextPage,
        loadType: refresh ? 1 : 2,
        sortType: sortType,
        goodClassifyId: key == _goodKey ? (state.classifyId ?? 0) : null,
      );
      if (!mounted) return;
      final loadedIds = res.threads.map((e) => e.effectiveId).toSet();
      final remaining = res.threadIds
          .where((id) => !loadedIds.contains(id))
          .toList();
      final generalTabs = res.generalTabs;
      final hasTabInfo = res.navTabs.isNotEmpty || res.tabs.isNotEmpty;
      setState(() {
        if (res.forum.name.isNotEmpty) _forum = res.forum;
        if (res.tbs.isNotEmpty) _tbs = res.tbs;
        if (hasTabInfo) _generalTabs = generalTabs;
        _mergeThreads(state, res.threads, refresh: refresh);
        state.pending = remaining;
        state.page = nextPage;
        state.hasMore = res.page.hasMore || remaining.isNotEmpty;
        state.loading = false;
        state.loadingMore = false;
        state.loaded = true;
      });
      if (refresh) _dropStaleSection();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        state.error = cleanError(e);
        state.loading = false;
        state.loadingMore = false;
        state.loaded = true;
      });
    }
  }

  void _mergeThreads(
    _SectionState state,
    List<TiebaThread> incoming, {
    required bool refresh,
  }) {
    if (refresh) {
      state.threads
        ..clear()
        ..addAll(incoming);
      return;
    }
    final seen = state.threads.map((e) => e.effectiveId).toSet();
    state.threads.addAll(incoming.where((t) => seen.add(t.effectiveId)));
  }

  /// 分区表随吧主页响应刷新，当前分区若已不存在就退回「最新」。
  void _dropStaleSection() {
    final tabs = _stripTabs;
    if (tabs.any((tab) => tab.value == _section)) return;
    _section = tabs.first.value;
    unawaited(_load(key: _section, refresh: true));
  }

  /// 下拉刷新、失败重试与右下角按钮共用；上一次没回来时再点直接丢弃，
  /// 否则两次请求会各自入列、把列表刷新成两份游标。
  Future<void> _refreshCurrent() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _load(key: _section, refresh: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 分区切换 / 排序菜单
  // ---------------------------------------------------------------------------

  void _switchSection(String key) {
    if (key == _section) return;
    final outgoing = _sections[_section];
    if (outgoing != null && _scroll.hasClients) {
      outgoing.offset = _scroll.offset;
    }
    final incoming = _stateOf(key);
    setState(() => _section = key);
    if (!incoming.loaded && !incoming.loading) {
      unawaited(_load(key: key, refresh: true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = incoming.offset.clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if ((_scroll.offset - target).abs() > 1) _scroll.jumpTo(target);
    });
  }

  void _switchSectionBy(int step) {
    final tabs = _stripTabs;
    if (tabs.length < 2) return;
    final index = tabs.indexWhere((tab) => tab.value == _section);
    final next = (index < 0 ? 0 : index) + step;
    if (next < 0 || next >= tabs.length) return;
    HapticFeedback.selectionClick();
    _switchSection(tabs[next].value);
  }

  Future<void> _pickLatestSort() async {
    final settings = context.read<FrostedSettings>();
    final current = settings.defaultSortType.clamp(0, 1);
    final picked = await showFrostedChoices<int>(
      context,
      title: '最新排序',
      choices: [
        FrostedChoice(
          value: 0,
          label: '按回复时间',
          subtitle: '最近有人回复的帖子在前',
          selected: current == 0,
        ),
        FrostedChoice(
          value: 1,
          label: '按发帖时间',
          subtitle: '新发布的帖子在前',
          selected: current == 1,
        ),
      ],
    );
    if (picked == null || !mounted || picked == current) return;
    await settings.setDefaultSortType(picked);
    if (!mounted) return;
    _reloadSection(_latestKey, sortType: picked);
  }

  Future<void> _pickSectionSort(ForumTab tab) async {
    final state = _stateOf('$_tabKeyPrefix${tab.tabId}');
    final picked = await showFrostedChoices<int>(
      context,
      title: '${tab.tabName}排序',
      choices: [
        for (final option in tab.sortMenu)
          FrostedChoice(
            value: option.sortType,
            label: option.sortName,
            selected: option.sortType == state.sortType,
          ),
      ],
    );
    if (picked == null || !mounted || picked == state.sortType) return;
    _reloadSection('$_tabKeyPrefix${tab.tabId}', sortType: picked);
  }

  void _reloadSection(String key, {int? sortType}) {
    final state = _stateOf(key)..reset();
    if (sortType != null) state.sortType = sortType;
    unawaited(_load(key: key, refresh: true));
  }

  Future<void> _handleSign() async {
    if (_signing) return;
    if (!await ensureLoggedIn(context, reason: '登录后即可在吧内签到')) return;
    if (!mounted || _forum.id <= 0) return;
    setState(() => _signing = true);
    try {
      final res = await context.read<TiebaRepo>().signForum(
        forumId: _forum.id,
        forumName: _forum.name,
        tbsOverride: _tbs,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _forum = _forum.copyWith(
          isSign: true,
          curScore:
              _forum.curScore +
              (res.signBonusPoint > 0 ? res.signBonusPoint : 0),
          contSignNum: res.contSignNum > 0
              ? res.contSignNum
              : _forum.contSignNum + 1,
          signRank: res.userSignRank,
        );
        _signing = false;
      });
      final extra = res.signBonusPoint > 0 ? ' +${res.signBonusPoint}经验' : '';
      showFrostedToast(context, '签到成功$extra');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _signing = false);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  Future<void> _handleFollowForum() async {
    if (!await ensureLoggedIn(context, reason: '登录后即可关注贴吧')) return;
    if (!mounted || _forum.id <= 0) return;
    final nextLike = !_forum.isLike;
    final prev = _forum;
    HapticFeedback.selectionClick();
    setState(() {
      _forum = _forum.copyWith(
        isLike: nextLike,
        memberNum: (_forum.memberNum + (nextLike ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
    try {
      await context.read<TiebaRepo>().toggleLikeForum(
        forumId: _forum.id,
        forumName: _forum.name,
        like: nextLike,
        tbsOverride: _tbs,
      );
      if (mounted) {
        showFrostedToast(context, nextLike ? '已关注 ${_forum.name}吧' : '已取消关注');
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _forum = prev);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  Future<void> _showMoreMenu() async {
    final picked = await showFrostedChoices<String>(
      context,
      title: '${_forum.name}吧',
      choices: const [
        FrostedChoice(value: 'detail', label: '吧资料'),
        FrostedChoice(value: 'rule', label: '吧规'),
        FrostedChoice(value: 'bawu', label: '吧务管理'),
        FrostedChoice(value: 'search', label: '吧内搜索'),
        FrostedChoice(value: 'compose', label: '发新帖'),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'detail':
        if (_forum.id > 0) {
          await openForumDetail(
            context,
            forumId: _forum.id,
            forumName: _forum.name,
          );
        }
      case 'rule':
        if (_forum.id > 0) {
          await openForumRule(
            context,
            forumId: _forum.id,
            forumName: _forum.name,
          );
        }
      case 'bawu':
        await openBawuConsole(context, _forumName);
      case 'search':
        await openSearch(context, forumName: _forum.name);
      case 'compose':
        if (!await ensureLoggedIn(context, reason: '登录后即可发帖')) return;
        if (!mounted || _forum.id <= 0) return;
        final posted = await openComposeThread(
          context,
          forumId: _forum.id,
          forumName: _forum.name,
          tbs: _tbs,
        );
        if (posted == true && mounted) unawaited(_refreshCurrent());
    }
  }

  Future<void> _toggleAgree(int idx) async {
    final state = _sections[_section];
    if (state == null || idx < 0 || idx >= state.threads.length) return;
    if (!await ensureLoggedIn(context, reason: '登录后即可点赞')) return;
    if (!mounted) return;
    final thread = state.threads[idx];
    final nextAgree = !thread.agree.isAgreed;
    setState(
      () => state.threads[idx] = thread.copyWith(
        agree: thread.agree.toggleAgree(),
      ),
    );
    try {
      await context.read<TiebaRepo>().opAgree(
        threadId: thread.effectiveId,
        postId: thread.firstPostId,
        agree: nextAgree,
        objType: 3,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => state.threads[idx] = thread);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = _sections[_section];
    return PrismScaffold(
      bar: const ZeroAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildScrollBody(context),
          Positioned(
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: _ForumRefreshButton(
              refreshing: _refreshing || (state?.loading ?? false),
              onPressed: _refreshCurrent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollBody(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final scheme = context.colorScheme;
    final state = _sections[_section];
    final list = state?.threads ?? const <TiebaThread>[];

    return FrostedRefresh(
      topInset: topInset + ProfileHeaderDelegate.barHeight,
      onRefresh: _refreshCurrent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _swipeDx = 0,
        onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
        onHorizontalDragEnd: (details) {
          final width = context.size?.width ?? 0;
          final velocity = details.primaryVelocity ?? 0;
          final far = width > 0 && _swipeDx.abs() > width * 0.22;
          if (!far && velocity.abs() < 320) return;
          final step = _swipeDx != 0
              ? (_swipeDx < 0 ? 1 : -1)
              : (velocity < 0 ? 1 : -1);
          _switchSectionBy(step);
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileHeaderDelegate(
                topInset: topInset,
                nameLine: ProfileHeaderDelegate.nameLineOf(context),
                title: '$_forumName吧',
                avatarUrl: _forum.avatar,
                // 吧没有头图，顶图区留白收窄，给下面的等级/经验腾地方。
                coverHeight: 80,
                headerAccessory: _forum.userLevel > 0
                    ? _ForumLevelBar(forum: _forum)
                    : null,
                avatarRoundedSquare: true,
                showBack: true,
                onBack: () => Navigator.of(context).maybePop(),
                actions: [
                  (
                    glyph: FrostedGlyphs.search,
                    tooltip: '吧内搜索',
                    onPressed: () =>
                        openSearch(context, forumName: _forum.name),
                  ),
                  (
                    glyph: FrostedGlyphs.add,
                    tooltip: '发帖',
                    onPressed: () async {
                      if (!await ensureLoggedIn(
                        context,
                        reason: '登录后即可发帖',
                      )) {
                        return;
                      }
                      if (!context.mounted || _forum.id <= 0) return;
                      final ok = await openComposeThread(
                        context,
                        forumId: _forum.id,
                        forumName: _forum.name,
                        tbs: _tbs,
                      );
                      if (ok == true && mounted) {
                        unawaited(_refreshCurrent());
                      }
                    },
                  ),
                  (
                    glyph: FrostedGlyphs.more,
                    tooltip: '更多',
                    onPressed: _showMoreMenu,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _buildForumInfo(context, scheme)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SectionStripDelegate(
                fill: SurfaceLevel.page.colorOf(scheme),
                child: CapsuleTabStrip<String>(
                  tabs: _stripTabs,
                  value: _section,
                  onChanged: _switchSection,
                ),
              ),
            ),
            if (_section == _goodKey && _forum.goodClassifies.isNotEmpty)
              SliverToBoxAdapter(child: _buildClassifyRow(context, scheme)),
            ..._buildListSlivers(context, state, list),
          ],
        ),
      ),
    );
  }

  Widget _buildForumInfo(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_forum.slogan.isNotEmpty) ...[
            Text(
              _forum.slogan,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  joinMeta([
                    if (_forum.memberNum > 0)
                      '关注 ${formatCount(_forum.memberNum)}',
                    if (_forum.postNum > 0) '帖子 ${formatCount(_forum.postNum)}',
                  ]),
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              PressScale(
                scale: 0.94,
                child: FrostedTapSurface(
                  onPressed: _handleFollowForum,
                  pill: true,
                  fill: _forum.isLike
                      ? context.surfaceLevel.next.colorOf(scheme)
                      : scheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      _forum.isLike ? '已关注' : '关注',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(
                            color: _forum.isLike
                                ? scheme.onSurface
                                : scheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PressScale(
                scale: 0.94,
                child: FrostedTapSurface(
                  onPressed: _forum.isSign || _signing ? null : _handleSign,
                  pill: true,
                  fill: _forum.isSign
                      ? context.success.withValues(alpha: 0.14)
                      : scheme.primary.withValues(alpha: 0.14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      _signing ? '签到中' : (_forum.isSign ? '已签到' : '签到'),
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(
                            color: _forum.isSign
                                ? context.success
                                : scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassifyRow(BuildContext context, ColorScheme scheme) {
    final selectedId = _sections[_goodKey]?.classifyId ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final classify in _forum.goodClassifies)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PressScale(
                  scale: 0.94,
                  child: FrostedTapSurface(
                    onPressed: () {
                      final good = _stateOf(_goodKey);
                      if ((good.classifyId ?? 0) == classify.id) return;
                      HapticFeedback.selectionClick();
                      setState(() {
                        good.classifyId = classify.id;
                        good.reset();
                      });
                      unawaited(_load(key: _goodKey, refresh: true));
                    },
                    pill: true,
                    fill: selectedId == classify.id
                        ? scheme.primary
                        : context.surfaceLevel.next.colorOf(scheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        classify.name,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(
                              color: selectedId == classify.id
                                  ? scheme.onPrimary
                                  : scheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildListSlivers(
    BuildContext context,
    _SectionState? state,
    List<TiebaThread> threads,
  ) {
    final loading = state == null || state.loading;
    if (loading && threads.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                ThreadCardSkeleton(),
                SizedBox(height: 10),
                ThreadCardSkeleton(),
                SizedBox(height: 10),
                ThreadCardSkeleton(),
              ],
            ),
          ),
        ),
      ];
    }
    final error = state?.error;
    if (error != null && threads.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: FrostedEmpty(
            title: '加载贴吧失败',
            message: error,
            icon: FrostedGlyphs.forum,
            action: FilledButton(
              onPressed: _refreshCurrent,
              child: const Text('重试'),
            ),
          ),
        ),
      ];
    }
    if (threads.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: FrostedEmpty(title: '暂无帖子', icon: FrostedGlyphs.forum),
        ),
      ];
    }
    final loadingMore = state?.loadingMore ?? false;
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          14,
          10,
          14,
          // 给右下角悬浮刷新留出位置，别让它压住最后一张卡片的操作栏。
          MediaQuery.paddingOf(context).bottom + 24 + _ForumRefreshButton.size,
        ),
        sliver: SliverList.separated(
          itemCount: threads.length + (loadingMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            if (idx >= threads.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: FrostedLoading(),
              );
            }
            final t = threads[idx];
            return ThreadCard(
              key: ValueKey('frs-${t.effectiveId}'),
              thread: t,
              showForumBadge: false,
              // 置顶帖（公告、吧规一类）压成单行，别让置顶内容占掉半屏。
              compact: t.isTop,
              onTap: () => openThread(
                context,
                threadId: t.effectiveId,
                forumId: _forum.id,
                forumName: _forum.name,
                forumAvatar: _forum.avatar,
                initialTitle: t.displayTitle,
              ),
              onLongPress: () async {
                if (await showThreadContextMenu(context, t)) {
                  unawaited(_load(key: _section, refresh: true));
                }
              },
              onAuthorTap: t.author.id > 0
                  ? () => openUserProfile(
                      context,
                      uid: t.author.id,
                      portrait: t.author.portrait,
                      initialName: t.author.displayName,
                    )
                  : null,
              onAgreeTap: () => _toggleAgree(idx),
              onImageTap: (imgs, i) =>
                  openImageViewer(context, images: imgs, initialIndex: i),
            );
          },
        ),
      ),
    ];
  }
}

/// 吧主页右下角的悬浮刷新：列表看深了不必先滚回顶部再下拉。
class _ForumRefreshButton extends StatelessWidget {
  const _ForumRefreshButton({
    required this.refreshing,
    required this.onPressed,
  });

  static const double size = 46;

  final bool refreshing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: '刷新',
      child: PressScale(
        scale: 0.92,
        enabled: !refreshing,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: refreshing
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed();
                },
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: SurfaceLevel.floatingOf(scheme).colorOf(scheme),
              shadows: dockShadows(scheme),
              shape: AppShape.full,
            ),
            child: refreshing
                ? const ActivityIndicator(size: 18)
                : GlyphIcon(
                    FrostedGlyphs.refresh,
                    size: 20,
                    color: scheme.onSurface,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 单个分区的列表状态：切换分区后各自保留帖子、分页游标与滚动位置。
class _SectionState {
  _SectionState({required this.sortType});

  int sortType;
  int? classifyId;
  final List<TiebaThread> threads = [];
  List<int> pending = [];
  int page = 0;
  int lastThreadId = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  bool loaded = false;
  String? error;
  double offset = 0;

  /// 重新拉第一页前清干净，避免新旧两份列表叠加。
  void reset() {
    threads.clear();
    pending = [];
    page = 0;
    lastThreadId = 0;
    hasMore = true;
    loaded = false;
    error = null;
  }
}

/// 吸顶的帖子分区条：滚动时贴着折叠栏停住，随时能切分区。
class _SectionStripDelegate extends SliverPersistentHeaderDelegate {
  const _SectionStripDelegate({required this.child, required this.fill});

  static const double _height = CapsuleTabStrip.height + 16;

  final Widget child;
  final Color fill;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: fill,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SectionStripDelegate old) =>
      old.child != child || old.fill != fill;
}

/// 吧内等级与经验：等级徽标 + 等级头衔 + 经验进度条 + `当前/升级所需`。
///
/// 挂在折叠头的头像右侧（[ProfileHeaderDelegate.headerAccessory]），
/// 位置窄，所以拆两行：等级在上，进度条在下。
/// 未登录时接口不下发这几个字段（`userLevel` 为 0），整块不渲染。
class _ForumLevelBar extends StatelessWidget {
  const _ForumLevelBar({required this.forum});

  final TiebaForum forum;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final goal = forum.levelUpScore;
    final hasProgress = goal > 0 && forum.curScore > 0;
    final progress = hasProgress
        ? (forum.curScore / goal).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostedTag(
              label: 'Lv.${forum.userLevel}',
              color: forum.isSign ? context.success : scheme.primary,
            ),
            if (forum.levelName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  forum.levelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
        if (hasProgress) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: scheme.primary.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${forum.curScore}/$goal',
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
