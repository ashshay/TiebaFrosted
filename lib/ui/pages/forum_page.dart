import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/profile_header.dart';
import '../widgets/refresh.dart';
import '../widgets/skeleton.dart';
import '../widgets/thread_card.dart';

/// 贴吧主页：折叠头 + 关注/签到 + 最新回复/最新发布/精品 排序 + 发帖/吧资料/吧规。
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
  final ScrollController _scroll = ScrollController();

  TiebaForum _forum = const TiebaForum();
  List<TiebaThread> _threads = [];
  List<int> _pendingIds = [];
  String _tbs = '';
  int _sortType = 0; // 0=最新回复, 1=最新发布, -1=精品
  int? _goodClassifyId;
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _forum = TiebaForum(name: widget.forumName, avatar: widget.initialAvatar);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sortType = context.read<FrostedSettings>().defaultSortType;
      unawaited(_load(refresh: true));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 360 &&
        _hasMore &&
        !_loading &&
        !_loadingMore) {
      unawaited(_load(refresh: false));
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = _threads.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final repo = context.read<TiebaRepo>();
      if (!refresh && _pendingIds.isNotEmpty && _forum.id > 0) {
        final batch = _pendingIds.take(30).toList();
        _pendingIds = _pendingIds.skip(30).toList();
        final more = await repo.getForumThreadsByIds(
          forumId: _forum.id,
          forumName: _forum.name.isNotEmpty ? _forum.name : widget.forumName,
          threadIds: batch,
          page: _page,
          sortType: _sortType,
        );
        if (!mounted) return;
        final seen = _threads.map((e) => e.effectiveId).toSet();
        setState(() {
          _threads = [
            ..._threads,
            for (final t in more)
              if (seen.add(t.effectiveId)) t,
          ];
          _loadingMore = false;
        });
        return;
      }

      final nextPage = refresh ? 1 : _page + 1;
      final res = await repo.getForumPage(
        forumName: widget.forumName,
        page: nextPage,
        loadType: refresh ? 1 : 2,
        sortType: _sortType,
        goodClassifyId: _sortType == -1 ? (_goodClassifyId ?? 0) : null,
      );
      if (!mounted) return;
      final loadedIds = res.threads.map((e) => e.effectiveId).toSet();
      final remainingIds = res.threadIds
          .where((id) => !loadedIds.contains(id))
          .toList();
      setState(() {
        if (res.forum.name.isNotEmpty) _forum = res.forum;
        if (res.tbs.isNotEmpty) _tbs = res.tbs;
        if (refresh) {
          _threads = res.threads;
        } else {
          final seen = _threads.map((e) => e.effectiveId).toSet();
          _threads = [
            ..._threads,
            for (final t in res.threads)
              if (seen.add(t.effectiveId)) t,
          ];
        }
        _pendingIds = remainingIds;
        _page = nextPage;
        _hasMore = res.page.hasMore || remainingIds.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
        _loadingMore = false;
      });
    }
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
        if (posted == true && mounted) unawaited(_load(refresh: true));
    }
  }

  Future<void> _toggleAgree(int idx) async {
    if (!await ensureLoggedIn(context, reason: '登录后即可点赞')) return;
    if (!mounted) return;
    final t = _threads[idx];
    final nextAgree = !t.agree.isAgreed;
    setState(() => _threads[idx] = t.copyWith(agree: t.agree.toggleAgree()));
    try {
      await context.read<TiebaRepo>().opAgree(
        threadId: t.effectiveId,
        postId: t.firstPostId,
        agree: nextAgree,
        objType: 3,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _threads[idx] = t);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final scheme = context.colorScheme;

    return PrismScaffold(
      bar: const ZeroAppBar(),
      body: FrostedRefresh(
        topInset: topInset + ProfileHeaderDelegate.barHeight,
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: ProfileHeaderDelegate(
                topInset: topInset,
                nameLine: ProfileHeaderDelegate.nameLineOf(context),
                title: '${_forum.name.isNotEmpty ? _forum.name : widget.forumName}吧',
                avatarUrl: _forum.avatar,
                avatarRoundedSquare: true,
                showBack: true,
                onBack: () => Navigator.of(context).maybePop(),
                actions: [
                  (
                    glyph: FrostedGlyphs.search,
                    tooltip: '吧内搜索',
                    onPressed: () => openSearch(context, forumName: _forum.name),
                  ),
                  (
                    glyph: FrostedGlyphs.add,
                    tooltip: '发帖',
                    onPressed: () async {
                      if (!await ensureLoggedIn(context, reason: '登录后即可发帖')) {
                        return;
                      }
                      if (!context.mounted || _forum.id <= 0) return;
                      final ok = await openComposeThread(
                        context,
                        forumId: _forum.id,
                        forumName: _forum.name,
                        tbs: _tbs,
                      );
                      if (ok == true && context.mounted) {
                        unawaited(_load(refresh: true));
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
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
                              if (_forum.postNum > 0)
                                '帖子 ${formatCount(_forum.postNum)}',
                              if (_forum.userLevel > 0) 'Lv.${_forum.userLevel}',
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
                                style: AppTextStyle.footnote.of(context).copyWith(
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
                            onPressed: _forum.isSign || _signing
                                ? null
                                : _handleSign,
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
                                _signing
                                    ? '签到中'
                                    : (_forum.isSign ? '已签到' : '签到'),
                                style: AppTextStyle.footnote.of(context).copyWith(
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedControl<int>(
                            value: _sortType,
                            onChanged: (v) {
                              if (v == _sortType) return;
                              setState(() {
                                _sortType = v;
                                _goodClassifyId = null;
                                _threads = [];
                                _pendingIds = [];
                              });
                              unawaited(_load(refresh: true));
                            },
                            segments: const [
                              (0, '最新回复'),
                              (1, '最新发布'),
                              (-1, '精品'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_sortType == -1 && _forum.goodClassifies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in _forum.goodClassifies)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: FrostedTapSurface(
                                  onPressed: () {
                                    setState(() {
                                      _goodClassifyId = c.id;
                                      _threads = [];
                                    });
                                    unawaited(_load(refresh: true));
                                  },
                                  pill: true,
                                  fill: (_goodClassifyId ?? 0) == c.id
                                      ? scheme.primary
                                      : context.surfaceLevel.next.colorOf(
                                          scheme,
                                        ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    child: Text(
                                      c.name,
                                      style: AppTextStyle.caption1
                                          .of(context)
                                          .copyWith(
                                            color:
                                                (_goodClassifyId ?? 0) == c.id
                                                    ? scheme.onPrimary
                                                    : scheme.onSurface,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading && _threads.isEmpty)
              const SliverToBoxAdapter(
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
              )
            else if (_error != null && _threads.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: FrostedEmpty(
                  title: '加载贴吧失败',
                  message: _error,
                  icon: FrostedGlyphs.forum,
                  action: FilledButton(
                    onPressed: () => _load(refresh: true),
                    child: const Text('重试'),
                  ),
                ),
              )
            else if (_threads.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: FrostedEmpty(
                  title: '暂无帖子',
                  icon: FrostedGlyphs.forum,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  MediaQuery.paddingOf(context).bottom + 24,
                ),
                sliver: SliverList.separated(
                  itemCount: _threads.length + (_loadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    if (idx >= _threads.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: FrostedLoading(),
                      );
                    }
                    final t = _threads[idx];
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
                      onLongPress: () => showThreadContextMenu(context, t),
                      onAuthorTap: t.author.id > 0
                          ? () => openUserProfile(
                              context,
                              uid: t.author.id,
                              portrait: t.author.portrait,
                              initialName: t.author.displayName,
                            )
                          : null,
                      onAgreeTap: () => _toggleAgree(idx),
                      onImageTap: (imgs, i) => openImageViewer(
                        context,
                        images: imgs,
                        initialIndex: i,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
