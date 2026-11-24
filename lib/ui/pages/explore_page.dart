import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/store.dart';
import '../../data/tab_cache.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/capsule_tab_strip.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/skeleton.dart';
import '../widgets/thread_card.dart';

/// 发现视图：贴吧热议榜 + 热门话题横滑 + 分类热帖。
///
/// 只出内容，不带自己的顶栏与下拉刷新——它现在是「首页」的一个标签，
/// 由 [HomePage] 的顶栏统一驱动；刷新时透过 [GlobalKey] 调 [ExploreViewState.reload]。
class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => ExploreViewState();
}

class ExploreViewState extends State<ExploreView> {
  final ScrollController _scroll = ScrollController();
  HotThreadPageResult? _data;
  String _selectedTabCode = 'all';
  String _selectedTabId = '1';
  bool _loading = false;
  String? _error;

  String get _accountKey => context.read<FrostedStore>().activeUid ?? 'guest';

  /// 供外部（下拉刷新 / 双击底栏）重新拉取。
  Future<void> reload() => _load();

  /// 供外部（双击底栏「动态」）回顶并重新拉取。
  Future<void> scrollToTopAndReload() {
    if (_scroll.hasClients && _scroll.offset > 0) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    return _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_restoreOrLoad());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _restoreOrLoad() async {
    final cached = await TabSnapshotCache.instance.readFeedHot(_accountKey);
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _data = cached.data;
        _selectedTabCode = cached.tabCode;
        _selectedTabId = cached.tabId;
        _loading = false;
        _error = null;
      });
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final res = await context.read<TiebaRepo>().getHotThreads(
        tabCode: _selectedTabCode,
        tabId: _selectedTabId,
      );
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
      unawaited(
        TabSnapshotCache.instance.saveFeedHot(
          _accountKey,
          data: res,
          tabCode: _selectedTabCode,
          tabId: _selectedTabId,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
      });
    }
  }

  String _codeOf(ForumTab tab) => tab.tabCode.isNotEmpty ? tab.tabCode : 'all';

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);
    return _buildBody(context, scheme, top, bottom);
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme scheme,
    double top,
    double bottom,
  ) {
    if (_loading && _data == null) {
      return FeedSkeletonList(topInset: top);
    }
    if (_error != null && _data == null) {
      return FrostedEmpty(
        title: '加载发现内容失败',
        message: _error,
        icon: FrostedGlyphs.explore,
        action: FilledButton(onPressed: _load, child: const Text('重试')),
      );
    }
    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    final topics = data.topics;
    final threads = data.threads;
    final tabs = data.tabs;

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14, top + 8, 14, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topics.isNotEmpty) ...[
                  Row(
                    children: [
                      GlyphIcon(
                        FrostedGlyphs.flame,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '贴吧热议',
                        style: AppTextStyle.headline
                            .of(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      FrostedTapSurface(
                        onPressed: () => openHotTopicList(context),
                        pill: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '全部榜单',
                                style: AppTextStyle.footnote
                                    .of(context)
                                    .copyWith(color: scheme.primary),
                              ),
                              const SizedBox(width: 2),
                              GlyphIcon(
                                Glyphs.chevronForward,
                                size: 14,
                                color: scheme.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FrostedCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < topics.length && i < 6; i++) ...[
                          FrostedTapSurface(
                            onPressed: () => openHotTopicDetail(
                              context,
                              topicId: topics[i].topicId,
                              topicName: topics[i].topicName,
                            ),
                            radius: AppCorner.sm,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${i + 1}',
                                      style: AppTextStyle.headline
                                          .of(context)
                                          .copyWith(
                                            color: i < 3
                                                ? scheme.error
                                                : scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      topics[i].topicName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyle.subheadline
                                          .of(context)
                                          .copyWith(color: scheme.onSurface),
                                    ),
                                  ),
                                  if (topics[i].discussNum > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${formatCount(topics[i].discussNum)}热议',
                                      style: AppTextStyle.caption1
                                          .of(context)
                                          .copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          if (i < topics.length - 1 && i < 5)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 36,
                                right: 14,
                              ),
                              child: Container(
                                height: 0.5,
                                color: scheme.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (tabs.isNotEmpty) ...[
                  CapsuleTabStrip<String>(
                    tabs: [
                      // 接口只下发分类 tab，首页自己补一个「全部」，避免
                      // 未选分类时滑块停在第一个分类上说了不算。
                      const CapsuleTabItem(value: 'all', label: '全部'),
                      for (final t in tabs)
                        CapsuleTabItem(value: _codeOf(t), label: t.tabName),
                    ],
                    value: _selectedTabCode,
                    onChanged: (code) {
                      if (code == _selectedTabCode) return;
                      final tab = code == 'all'
                          ? null
                          : tabs.firstWhere(
                              (t) => _codeOf(t) == code,
                              orElse: () => tabs.first,
                            );
                      setState(() {
                        _selectedTabCode = code;
                        _selectedTabId = tab == null ? '1' : '${tab.tabId}';
                      });
                      unawaited(_load());
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        if (threads.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 48, 14, bottom + 48),
              child: const FrostedEmpty(
                title: '暂无热议帖子',
                icon: FrostedGlyphs.explore,
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, bottom),
            sliver: SliverList.separated(
              itemCount: threads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = threads[i];
                return ThreadCard(
                  key: ValueKey('hot-${t.effectiveId}'),
                  thread: t,
                  onTap: () => openThread(
                    context,
                    threadId: t.effectiveId,
                    forumId: t.forumId,
                    forumName: t.forumName,
                    initialTitle: t.displayTitle,
                  ),
                  onLongPress: () async {
                    if (await showThreadContextMenu(context, t)) {
                      unawaited(_load());
                    }
                  },
                  onCommentTap: () => openThread(
                    context,
                    threadId: t.effectiveId,
                    forumId: t.forumId,
                    forumName: t.forumName,
                    initialTitle: t.displayTitle,
                    focusReplies: true,
                  ),
                  onForumTap: () => openForum(context, t.forumName),
                  onAuthorTap: t.author.id > 0
                      ? () => openUserProfile(
                          context,
                          uid: t.author.id,
                          portrait: t.author.portrait,
                          initialName: t.author.displayName,
                        )
                      : null,
                  onImageTap: (imgs, idx) =>
                      openImageViewer(context, images: imgs, initialIndex: idx),
                );
              },
            ),
          ),
      ],
    );
  }
}
