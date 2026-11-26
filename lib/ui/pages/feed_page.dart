import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../../data/store.dart';
import '../../data/tab_cache.dart';
import '../chrome.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/refresh.dart';
import '../widgets/segmented_capsule.dart';
import '../widgets/skeleton.dart';
import '../widgets/swipe_pager.dart';
import '../widgets/thread_card.dart';
import 'explore_page.dart';

/// 动态页：原首页的「推荐」与「关注」两条流合并到底栏一格，顶栏分段切换。
///
/// 顶栏分段之外还能左右滑动切页（可在「设置 → 使用习惯」关掉）；双击底栏「动态」
/// 会把当前那条流刷新并回到顶部。
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const _tabs = ['推荐', '关注', '热榜'];

  final ScrollController _recScroll = ScrollController();
  final ScrollController _concernScroll = ScrollController();
  final GlobalKey<ExploreViewState> _exploreKey = GlobalKey<ExploreViewState>();
  ChromeController? _chrome;
  FrostedSettings? _settings;
  int _lastDefaultFeedTab = 0;
  int _tab = 0; // 0 = 推荐, 1 = 关注, 2 = 热榜
  bool _exploreMounted = false;
  int _lastFeedRefresh = 0;

  // 推荐流
  List<TiebaThread> _recThreads = [];
  bool _recLoading = false;
  bool _recLoadingMore = false;
  bool _recLoadedOnce = false;
  String? _recError;
  int _recPage = 1;

  // 关注流
  List<TiebaThread> _concernThreads = [];
  bool _concernLoading = false;
  bool _concernLoadingMore = false;
  String? _concernError;
  String _concernPageTag = '';
  int _concernLastUnix = 0;
  bool _concernHasMore = true;
  bool _concernLoadedOnce = false;

  String get _accountKey => context.read<FrostedStore>().activeUid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _settings = context.read<FrostedSettings>();
    _lastDefaultFeedTab = _settings!.defaultFeedTab.clamp(0, 2);
    _tab = _lastDefaultFeedTab;
    _settings!.addListener(_onSettingsChange);
    if (_tab == 2) _exploreMounted = true;
    _recScroll.addListener(_onRecScrollNearBottom);
    _concernScroll.addListener(_onConcernScrollNearBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chrome = context.read<ChromeController>();
      _lastFeedRefresh = _chrome!.feedRefreshCount;
      _chrome!.addListener(_onChromeChange);
      if (_tab == 0) {
        unawaited(_restoreOrLoadRec());
      } else if (_tab == 1) {
        unawaited(_restoreOrLoadConcern());
      }
    });
  }

  @override
  void dispose() {
    _settings?.removeListener(_onSettingsChange);
    _chrome?.removeListener(_onChromeChange);
    _recScroll.dispose();
    _concernScroll.dispose();
    super.dispose();
  }

  void _onSettingsChange() {
    if (!mounted) return;
    final nextDefault = _settings!.defaultFeedTab.clamp(0, 2);
    if (nextDefault == _lastDefaultFeedTab) return;
    _lastDefaultFeedTab = nextDefault;
    _switchTab(nextDefault);
  }

  Future<void> _restoreOrLoadRec() async {
    if (_recLoadedOnce) return;
    final cached = await TabSnapshotCache.instance.readFeedRec(_accountKey);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _recThreads = cached;
        _recLoading = false;
        _recError = null;
        _recLoadedOnce = true;
      });
      return;
    }
    await _loadRec(refresh: true);
  }

  Future<void> _restoreOrLoadConcern() async {
    if (_concernLoadedOnce) return;
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      setState(() {
        _concernThreads = [];
        _concernLoading = false;
        _concernLoadedOnce = true;
      });
      return;
    }
    final cached = await TabSnapshotCache.instance.readFeedConcern(_accountKey);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _concernThreads = cached.threads;
        _concernPageTag = cached.pageTag;
        _concernLastUnix = cached.requestUnix;
        _concernHasMore = cached.hasMore;
        _concernLoading = false;
        _concernError = null;
        _concernLoadedOnce = true;
      });
      return;
    }
    await _loadConcern(refresh: true);
  }

  void _onChromeChange() {
    if (!mounted) return;
    final count = context.read<ChromeController>().feedRefreshCount;
    if (count == _lastFeedRefresh) return;
    _lastFeedRefresh = count;
    if (_tab == 2) {
      unawaited(_exploreKey.currentState?.scrollToTopAndReload());
      return;
    }
    final activeScroll = _tab == 0 ? _recScroll : _concernScroll;
    if (activeScroll.hasClients && activeScroll.offset > 0) {
      activeScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(_refreshCurrentTab());
  }

  void _onRecScrollNearBottom() {
    if (!_recScroll.hasClients) return;
    final max = _recScroll.position.maxScrollExtent;
    if (max <= 0 || _recScroll.offset < max - 360) return;
    if (_tab == 0 && !_recLoading && !_recLoadingMore) {
      unawaited(_loadRec(refresh: false));
    }
  }

  void _onConcernScrollNearBottom() {
    if (!_concernScroll.hasClients) return;
    final max = _concernScroll.position.maxScrollExtent;
    if (max <= 0 || _concernScroll.offset < max - 360) return;
    if (_tab == 1 &&
        _concernHasMore &&
        !_concernLoading &&
        !_concernLoadingMore) {
      unawaited(_loadConcern(refresh: false));
    }
  }

  Future<void> _refreshCurrentTab() async {
    switch (_tab) {
      case 0:
        await _loadRec(refresh: true);
      case 1:
        await _loadConcern(refresh: true);
      case 2:
        await _exploreKey.currentState?.reload();
    }
  }

  void _switchTab(int next) {
    if (next == _tab) return;
    setState(() {
      _tab = next;
      if (next == 2) _exploreMounted = true;
    });
    context.read<ChromeController>().setHidden(false);
    if (next == 0 && !_recLoadedOnce) {
      unawaited(_restoreOrLoadRec());
    } else if (next == 1 && !_concernLoadedOnce) {
      unawaited(_restoreOrLoadConcern());
    }
  }

  /// 横滑切页：和点分段走同一条路，只是多给一次轻震。
  void _swipeToTab(int next) {
    if (next == _tab) return;
    HapticFeedback.selectionClick();
    _switchTab(next);
  }

  Future<void> _loadRec({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _recLoading = _recThreads.isEmpty;
        _recError = null;
      });
    } else {
      setState(() => _recLoadingMore = true);
    }
    try {
      final repo = context.read<TiebaRepo>();
      final nextPage = refresh ? 1 : _recPage + 1;
      final list = await repo.getPersonalized(
        loadType: refresh ? 1 : 2,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _recThreads = list;
          _recPage = 1;
        } else {
          final seen = _recThreads.map((e) => e.effectiveId).toSet();
          _recThreads = [
            ..._recThreads,
            for (final t in list)
              if (seen.add(t.effectiveId)) t,
          ];
          _recPage = nextPage;
        }
        _recLoading = false;
        _recLoadingMore = false;
        _recLoadedOnce = true;
      });
      unawaited(TabSnapshotCache.instance.saveFeedRec(_accountKey, _recThreads));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _recError = cleanError(e);
        _recLoading = false;
        _recLoadingMore = false;
        _recLoadedOnce = true;
      });
    }
  }

  Future<void> _loadConcern({required bool refresh}) async {
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      setState(() {
        _concernThreads = [];
        _concernLoading = false;
        _concernLoadedOnce = true;
      });
      return;
    }
    if (refresh) {
      setState(() {
        _concernLoading = _concernThreads.isEmpty;
        _concernError = null;
      });
    } else {
      setState(() => _concernLoadingMore = true);
    }
    try {
      final res = await repo.getConcernFeed(
        pageTag: refresh ? '' : _concernPageTag,
        lastRequestUnix: refresh ? 0 : _concernLastUnix,
        loadType: refresh ? 1 : 2,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) {
          _concernThreads = res.threads;
        } else {
          final seen = _concernThreads.map((e) => e.effectiveId).toSet();
          _concernThreads = [
            ..._concernThreads,
            for (final t in res.threads)
              if (seen.add(t.effectiveId)) t,
          ];
        }
        _concernPageTag = res.pageTag;
        _concernLastUnix = res.requestUnix;
        _concernHasMore = res.hasMore && res.threads.isNotEmpty;
        _concernLoading = false;
        _concernLoadingMore = false;
        _concernLoadedOnce = true;
      });
      unawaited(
        TabSnapshotCache.instance.saveFeedConcern(
          _accountKey,
          ConcernPageResult(
            threads: _concernThreads,
            pageTag: _concernPageTag,
            hasMore: _concernHasMore,
            requestUnix: _concernLastUnix,
          ),
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _concernError = cleanError(e);
        _concernLoading = false;
        _concernLoadingMore = false;
        _concernLoadedOnce = true;
      });
    }
  }

  Future<void> _toggleAgree(List<TiebaThread> list, int index) async {
    if (!await ensureLoggedIn(context, reason: '登录后即可给帖子点赞')) return;
    if (!mounted) return;
    final thread = list[index];
    final settings = context.read<FrostedSettings>();
    if (settings.confirmBeforeLike && !thread.agree.isAgreed) {
      final ok = await showFrostedConfirm(
        context,
        title: '确认点赞',
        message: '给「${thread.displayTitle}」点赞？',
      );
      if (ok != true || !mounted) return;
    }
    final nextAgree = !thread.agree.isAgreed;
    setState(() {
      list[index] = thread.copyWith(agree: thread.agree.toggleAgree());
    });
    try {
      await context.read<TiebaRepo>().opAgree(
        threadId: thread.effectiveId,
        postId: thread.firstPostId,
        agree: nextAgree,
        objType: 3,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => list[index] = thread);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.read<ChromeController>();
    final store = context.watch<FrostedStore>();
    final swipeEnabled = context.select<FrostedSettings, bool>(
      (s) => s.swipeSwitchFeed,
    );

    return PrismScaffold(
      bar: FrostedAppBar(
        bindChrome: true,
        title: SizedBox(
          width: 228,
          child: FrostedSegmentedControl<int>(
            value: _tab,
            onChanged: _switchTab,
            segments: const [
              (0, '推荐'),
              (1, '关注'),
              (2, '热榜'),
            ],
          ),
        ),
        actions: [
          PressScale(
            scale: 0.92,
            child: IconButton(
              onPressed: () => openSearch(context),
              tooltip: '搜索',
              icon: const GlyphIcon(FrostedGlyphs.search, size: 20),
            ),
          ),
          if (store.isLoggedIn)
            PressScale(
              scale: 0.92,
              child: IconButton(
                onPressed: () => runOneClickOkSign(context),
                tooltip: '一键签到',
                icon: const GlyphIcon(FrostedGlyphs.calendarCheck, size: 20),
              ),
            ),
          PressScale(
            scale: 0.92,
            child: IconButton(
              onPressed: () => openSettings(context),
              tooltip: '设置',
              icon: const GlyphIcon(FrostedGlyphs.wrench, size: 20),
            ),
          ),
        ],
      ),
      body: ChromeScrollListener(
        onHiddenChanged: chrome.setHidden,
        enabled: context.select<FrostedSettings, bool>(
          (s) => s.autoHideBars,
        ),
        child: FrostedRefresh(
          topInset: pageTopInset(context),
          onRefresh: _refreshCurrentTab,
          child: SwipePager(
            index: _tab,
            count: _tabs.length,
            enabled: swipeEnabled,
            onIndexChanged: _swipeToTab,
            child: IndexedStack(
              index: _tab,
              children: [
                _buildRecTab(context),
                _buildConcernTab(context, store),
                _exploreMounted
                    ? ExploreView(key: _exploreKey)
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecTab(BuildContext context) {
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);

    if (!_recLoadedOnce && !_recLoading && _recThreads.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_recLoading && _recThreads.isEmpty) {
      return FeedSkeletonList(topInset: top);
    }
    if (_recError != null && _recThreads.isEmpty) {
      return FrostedEmpty(
        title: '加载推荐失败',
        message: _recError,
        icon: FrostedGlyphs.home,
        action: FilledButton(
          onPressed: () => _loadRec(refresh: true),
          child: const Text('重试'),
        ),
      );
    }
    if (_recThreads.isEmpty) {
      return FrostedEmpty(
        title: '暂无推荐内容',
        message: '下拉刷新试试，或通过顶部搜索进入任意贴吧',
        icon: FrostedGlyphs.home,
        action: FilledButton(
          onPressed: () => _loadRec(refresh: true),
          child: const Text('刷新'),
        ),
      );
    }
    return ListView.separated(
      controller: _recScroll,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, bottom),
      itemCount: _recThreads.length + (_recLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        if (idx >= _recThreads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: FrostedLoading(),
          );
        }
        final t = _recThreads[idx];
        return ThreadCard(
          key: ValueKey('rec-${t.effectiveId}'),
          thread: t,
          onTap: () => openThread(
            context,
            threadId: t.effectiveId,
            forumId: t.forumId,
            forumName: t.forumName,
            forumAvatar: t.forumAvatar,
            initialTitle: t.displayTitle,
          ),
          onLongPress: () async {
            if (await showThreadContextMenu(context, t)) {
              unawaited(_refreshCurrentTab());
            }
          },
          onForumTap: () => openForum(context, t.forumName),
          onAuthorTap: t.author.id > 0
              ? () => openUserProfile(
                  context,
                  uid: t.author.id,
                  portrait: t.author.portrait,
                  initialName: t.author.displayName,
                )
              : null,
          onAgreeTap: () => _toggleAgree(_recThreads, idx),
          onCommentTap: () => openThread(
            context,
            threadId: t.effectiveId,
            forumId: t.forumId,
            forumName: t.forumName,
            forumAvatar: t.forumAvatar,
            initialTitle: t.displayTitle,
            focusReplies: true,
          ),
          onImageTap: (imgs, i) =>
              openImageViewer(context, images: imgs, initialIndex: i),
        );
      },
    );
  }

  Widget _buildConcernTab(BuildContext context, FrostedStore store) {
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);

    if (!store.isLoggedIn) {
      return FrostedEmpty(
        title: '登录后查看关注动态',
        message: '这里将展示你关注的贴吧和吧友的最新动态',
        icon: FrostedGlyphs.follow,
        action: FilledButton(
          onPressed: () => openLogin(context),
          child: const Text('登录贴吧'),
        ),
      );
    }
    if (!_concernLoadedOnce && !_concernLoading && _concernThreads.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_concernLoading && _concernThreads.isEmpty) {
      return FeedSkeletonList(topInset: top);
    }
    if (_concernError != null && _concernThreads.isEmpty) {
      return FrostedEmpty(
        title: '加载关注动态失败',
        message: _concernError,
        icon: FrostedGlyphs.follow,
        action: FilledButton(
          onPressed: () => _loadConcern(refresh: true),
          child: const Text('重试'),
        ),
      );
    }
    if (_concernThreads.isEmpty) {
      return FrostedEmpty(
        title: '暂无关注动态',
        message: '下拉刷新，或去发现页看看热门内容',
        icon: FrostedGlyphs.follow,
        action: FilledButton(
          onPressed: () => _loadConcern(refresh: true),
          child: const Text('刷新'),
        ),
      );
    }
    return ListView.separated(
      controller: _concernScroll,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, bottom),
      itemCount: _concernThreads.length + (_concernLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        if (idx >= _concernThreads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: FrostedLoading(),
          );
        }
        final t = _concernThreads[idx];
        return ThreadCard(
          key: ValueKey('concern-${t.effectiveId}'),
          thread: t,
          onTap: () => openThread(
            context,
            threadId: t.effectiveId,
            forumId: t.forumId,
            forumName: t.forumName,
            forumAvatar: t.forumAvatar,
            initialTitle: t.displayTitle,
          ),
          onLongPress: () async {
            if (await showThreadContextMenu(context, t)) {
              unawaited(_refreshCurrentTab());
            }
          },
          onForumTap: () => openForum(context, t.forumName),
          onAuthorTap: t.author.id > 0
              ? () => openUserProfile(
                  context,
                  uid: t.author.id,
                  portrait: t.author.portrait,
                  initialName: t.author.displayName,
                )
              : null,
          onAgreeTap: () => _toggleAgree(_concernThreads, idx),
          onCommentTap: () => openThread(
            context,
            threadId: t.effectiveId,
            forumId: t.forumId,
            forumName: t.forumName,
            forumAvatar: t.forumAvatar,
            initialTitle: t.displayTitle,
            focusReplies: true,
          ),
          onImageTap: (imgs, i) =>
              openImageViewer(context, images: imgs, initialIndex: i),
        );
      },
    );
  }
}
