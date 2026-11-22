import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../../data/store.dart';
import '../chrome.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/forum_card.dart';
import '../widgets/glyphs.dart';
import '../widgets/press_scale.dart';
import '../widgets/refresh.dart';
import '../widgets/visited_forums_bar.dart';

/// 首页：进吧（关注列表）与发现（热议）两栏，顶栏分段切换。
///
/// 「推荐 / 关注」已合并到独立的「动态」标签；双击底栏「首页」刷新当前这一栏。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();
  ChromeController? _chrome;
  int _lastHomeRefresh = 0;

  List<FollowedForum> _forums = [];
  bool _forumsLoading = false;
  String? _forumsError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollNearBottom);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chrome = context.read<ChromeController>();
      _lastHomeRefresh = _chrome!.homeRefreshCount;
      _chrome!.addListener(_onChromeChange);
      unawaited(_loadForums());
    });
  }

  @override
  void dispose() {
    _chrome?.removeListener(_onChromeChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChromeChange() {
    if (!mounted) return;
    final count = context.read<ChromeController>().homeRefreshCount;
    if (count == _lastHomeRefresh) return;
    _lastHomeRefresh = count;
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(_loadForums());
  }

  void _onScrollNearBottom() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0 || _scroll.offset < max - 360) return;
  }

  Future<void> _loadForums() async {
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      setState(() {
        _forums = [];
        _forumsLoading = false;
      });
      return;
    }
    setState(() {
      _forumsLoading = _forums.isEmpty;
      _forumsError = null;
    });
    try {
      final list = await repo.getFollowedForums();
      if (!mounted) return;
      setState(() {
        _forums = list;
        _forumsLoading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _forumsError = cleanError(e);
        _forumsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<ChromeController>();
    final store = context.watch<FrostedStore>();
    final settings = context.watch<FrostedSettings>();

    return PrismScaffold(
      bar: FrostedAppBar(
        hidden: chrome.hidden,
        title: Text(
          '关注贴吧',
          style: AppTextStyle.title3
              .of(context)
              .copyWith(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          PressScale(
            scale: 0.92,
            child: IconButton(
              onPressed: () =>
                  settings.setForumListSingle(!settings.forumListSingle),
              tooltip: settings.forumListSingle ? '切换为网格排列' : '切换为单列排列',
              icon: GlyphIcon(
                settings.forumListSingle
                    ? FrostedGlyphs.layoutGrid
                    : FrostedGlyphs.layoutList,
                size: 20,
              ),
            ),
          ),
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
        child: FrostedRefresh(
          topInset: pageTopInset(context),
          onRefresh: _loadForums,
          child: _buildForums(context, store, settings),
        ),
      ),
    );
  }

  Widget _buildForums(
    BuildContext context,
    FrostedStore store,
    FrostedSettings settings,
  ) {
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);

    if (!store.isLoggedIn) {
      return FrostedEmpty(
        title: '登录后查看关注的贴吧',
        message: '也可直接搜索任意贴吧浏览，无需登录',
        icon: FrostedGlyphs.forum,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => openLogin(context),
              child: const Text('登录贴吧'),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => openSearch(context),
              child: const Text('搜索贴吧'),
            ),
          ],
        ),
      );
    }
    if (_forumsLoading && _forums.isEmpty) {
      return const FrostedLoading(label: '加载贴吧列表中...');
    }
    if (_forumsError != null && _forums.isEmpty) {
      return FrostedEmpty(
        title: '获取贴吧列表失败',
        message: _forumsError,
        icon: FrostedGlyphs.forum,
        action: FilledButton(onPressed: _loadForums, child: const Text('重试')),
      );
    }
    if (_forums.isEmpty) {
      return FrostedEmpty(
        title: '还没有关注的贴吧',
        message: '去搜搜感兴趣的贴吧并关注吧',
        icon: FrostedGlyphs.forum,
        action: FilledButton(
          onPressed: () => openSearch(context),
          child: const Text('搜索贴吧'),
        ),
      );
    }

    final header = settings.homeShowHistoryForum && store.visitedForums.isNotEmpty
        ? VisitedForumsBar(
            forums: store.visitedForums,
            onForumTap: (r) => openForum(context, r.itemId),
            onOpenAll: () => openHistory(context),
          )
        : null;

    Widget buildForum(int idx, {required bool compact}) {
      final f = _forums[idx];
      final pinned = store.isTopForum(f.forumName);
      return ForumCard(
        key: ValueKey('forum-${f.forumId}'),
        name: f.forumName,
        avatar: f.avatar,
        subtitle: joinMeta([
          if (f.levelName.isNotEmpty) f.levelName,
          if (f.curScore > 0) '经验 ${f.curScore}/${f.levelUpScore}',
        ]),
        levelId: f.levelId,
        isSigned: f.isSign,
        isPinned: pinned,
        compact: compact,
        onTap: () => openForum(context, f.forumName, initialAvatar: f.avatar),
        onLongPress: () async {
          await store.toggleTopForum(f.forumName);
          if (context.mounted) {
            showFrostedToast(
              context,
              pinned ? '已取消置顶 ${f.forumName}吧' : '已置顶 ${f.forumName}吧',
            );
            unawaited(_loadForums());
          }
        },
      );
    }

    // 网格固定两列：自适应列宽在窄屏会挤成三列，吧名被截成「xperi…」这种。
    if (!settings.forumListSingle) {
      return CustomScrollView(
        controller: _scroll,
        slivers: [
          if (header != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
                child: header,
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, bottom),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 52,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _forums.length,
              itemBuilder: (_, idx) => buildForum(idx, compact: true),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, bottom),
      itemCount: _forums.length + (header != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        if (header != null) {
          if (idx == 0) return header;
          return buildForum(idx - 1, compact: false);
        }
        return buildForum(idx, compact: false);
      },
    );
  }
}
