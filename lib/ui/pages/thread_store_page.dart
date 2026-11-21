import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';

/// 我的收藏帖子列表页（支持长按取消收藏）。
class ThreadStorePage extends StatefulWidget {
  const ThreadStorePage({super.key});

  @override
  State<ThreadStorePage> createState() => _ThreadStorePageState();
}

class _ThreadStorePageState extends State<ThreadStorePage> {
  final ScrollController _scroll = ScrollController();
  List<ThreadStoreItem> _items = [];
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_load(refresh: true)),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 300 &&
        _hasMore &&
        !_loading &&
        !_loadingMore) {
      unawaited(_load(refresh: false));
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = _items.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final offset = refresh ? 0 : _items.length;
      final list = await context.read<TiebaRepo>().getThreadStore(
        pageSize: 20,
        offset: offset,
      );
      if (!mounted) return;
      setState(() {
        _items = refresh ? list : [..._items, ...list];
        _hasMore = list.length >= 20;
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

  Future<void> _remove(ThreadStoreItem item) async {
    final ok = await showFrostedConfirm(
      context,
      title: '取消收藏',
      message: '确定取消收藏「${item.title}」？',
      destructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<TiebaRepo>().toggleThreadStore(
        threadId: item.threadId,
        collect: false,
      );
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.threadId == item.threadId));
      showFrostedToast(context, '已取消收藏');
    } on Object catch (e) {
      if (mounted) {
        showFrostedToast(context, cleanError(e), level: BannerLevel.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedPage(
      title: '我的收藏',
      body: FrostedRefresh(
        topInset: pageTopInset(context),
        onRefresh: () => _load(refresh: true),
        child: _loading && _items.isEmpty
            ? const FrostedLoading(label: '加载收藏中...')
            : _error != null && _items.isEmpty
                ? FrostedEmpty(
                    title: '加载失败',
                    message: _error,
                    icon: FrostedGlyphs.bookmark,
                    action: FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('重试'),
                    ),
                  )
                : _items.isEmpty
                    ? const FrostedEmpty(
                        title: '还没有收藏的帖子',
                        icon: FrostedGlyphs.bookmark,
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(
                          14,
                          pageTopInset(context) + 8,
                          14,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          if (idx >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: FrostedLoading(),
                            );
                          }
                          final item = _items[idx];
                          return FrostedCard(
                            onPressed: item.isDeleted
                                ? null
                                : () => openThread(
                                    context,
                                    threadId: item.threadId,
                                    forumName: item.forumName,
                                    postId: item.markPid > 0
                                        ? item.markPid
                                        : null,
                                    initialTitle: item.title,
                                    fromStore: true,
                                  ),
                            onLongPress: () => _remove(item),
                            child: Row(
                              children: [
                                Avatar(url: item.authorPortrait, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.isDeleted
                                            ? '（帖子已删除）'
                                            : item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyle.subheadline
                                            .of(context)
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        joinMeta([
                                          if (item.forumName.isNotEmpty)
                                            '${item.forumName}吧',
                                          item.authorName,
                                        ]),
                                        style: AppTextStyle.caption1
                                            .of(context)
                                            .copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
