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

/// 独立搜帖页（也导出 `SearchThreadView` 嵌入搜索主页）。
class SearchThreadPage extends StatelessWidget {
  const SearchThreadPage({
    super.key,
    required this.keyword,
    this.forumName,
  });

  final String keyword;
  final String? forumName;

  @override
  Widget build(BuildContext context) {
    return FrostedPage(
      title: forumName != null ? '$forumName吧搜帖' : '搜帖：$keyword',
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: SearchThreadView(keyword: keyword, forumName: forumName),
      ),
    );
  }
}

class SearchThreadView extends StatefulWidget {
  const SearchThreadView({
    super.key,
    required this.keyword,
    this.forumName,
  });

  final String keyword;
  final String? forumName;

  @override
  State<SearchThreadView> createState() => _SearchThreadViewState();
}

class _SearchThreadViewState extends State<SearchThreadView> {
  final ScrollController _scroll = ScrollController();
  List<SearchThreadItem> _items = [];
  int _order = 2; // 2=相关, 1=最新, 0=最早
  int _page = 1;
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
      final nextPage = refresh ? 1 : _page + 1;
      final res = await context.read<TiebaRepo>().searchThread(
        keyword: widget.keyword,
        page: nextPage,
        order: _order,
        forumName: widget.forumName,
      );
      if (!mounted) return;
      setState(() {
        _items = refresh ? res.items : [..._items, ...res.items];
        _page = nextPage;
        _hasMore = res.hasMore && res.items.isNotEmpty;
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              for (final (code, label) in const [
                (2, '相关性'),
                (1, '最新'),
                (0, '最早'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FrostedTapSurface(
                    onPressed: () {
                      if (_order == code) return;
                      setState(() {
                        _order = code;
                        _items = [];
                      });
                      unawaited(_load(refresh: true));
                    },
                    pill: true,
                    fill: _order == code
                        ? scheme.primary
                        : SurfaceLevel.card.colorOf(scheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Text(
                        label,
                        style: AppTextStyle.caption1.of(context).copyWith(
                          color: _order == code
                              ? scheme.onPrimary
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _items.isEmpty
              ? const FrostedLoading(label: '搜索帖子中...')
              : _error != null && _items.isEmpty
                  ? FrostedEmpty(
                      title: '搜索失败',
                      message: _error,
                      icon: FrostedGlyphs.search,
                      action: FilledButton(
                        onPressed: () => _load(refresh: true),
                        child: const Text('重试'),
                      ),
                    )
                  : _items.isEmpty
                      ? const FrostedEmpty(
                          title: '没有找到相关帖子',
                          icon: FrostedGlyphs.search,
                        )
                      : ListView.separated(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                            14,
                            2,
                            14,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            if (idx >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: FrostedLoading(),
                              );
                            }
                            final item = _items[idx];
                            return FrostedCard(
                              onPressed: () => openThread(
                                context,
                                threadId: item.threadId,
                                forumId: item.forumId,
                                forumName: item.forumName,
                                postId: item.postId > 0 ? item.postId : null,
                                initialTitle: item.title,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title.isNotEmpty
                                        ? item.title
                                        : item.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyle.headline
                                        .of(context)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (item.content.isNotEmpty &&
                                      item.content != item.title) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      item.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyle.subheadline
                                          .of(context)
                                          .copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    joinMeta([
                                      if (item.forumName.isNotEmpty)
                                        '${item.forumName}吧',
                                      if (item.authorName.isNotEmpty)
                                        item.authorName,
                                      if (item.time > 0)
                                        formatTiebaTime(item.time),
                                      if (item.replyNum > 0)
                                        '${formatCount(item.replyNum)}回复',
                                    ]),
                                    style: AppTextStyle.caption1
                                        .of(context)
                                        .copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
