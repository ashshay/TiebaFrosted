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
import '../widgets/thread_card.dart';

/// 热门话题详情页。
class HotTopicDetailPage extends StatefulWidget {
  const HotTopicDetailPage({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  final int topicId;
  final String topicName;

  @override
  State<HotTopicDetailPage> createState() => _HotTopicDetailPageState();
}

class _HotTopicDetailPageState extends State<HotTopicDetailPage> {
  final ScrollController _scroll = ScrollController();
  HotTopicDetailResult? _detail;
  List<TiebaThread> _threads = [];
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
        _loading = _threads.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final nextPage = refresh ? 1 : _page + 1;
      // 服务端只在 pn>1 且带 last_id 时才下发第二批讨论，只给 pn 会返回空列表。
      final lastId = refresh || _threads.isEmpty
          ? ''
          : '${_threads.last.effectiveId}';
      final res = await context.read<TiebaRepo>().getHotTopicDetail(
        topicId: widget.topicId,
        topicName: widget.topicName,
        page: nextPage,
        offset: refresh ? 0 : _threads.length,
        lastId: lastId,
      );
      if (!mounted) return;
      final seen = refresh
          ? <int>{}
          : {for (final t in _threads) t.effectiveId};
      final added = [
        for (final t in res.threads)
          if (seen.add(t.effectiveId)) t,
      ];
      setState(() {
        // 翻页响应缺 topic_info 时保留首屏的话题资料，别把简介和讨论数清空。
        if (refresh || res.topicDesc.isNotEmpty || res.discussNum > 0) {
          _detail = res;
        }
        _threads = refresh ? added : [..._threads, ...added];
        _page = nextPage;
        // 没有新帖子就停，避免同一批数据被反复追加。
        _hasMore = res.hasMore && added.isNotEmpty;
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
    return FrostedPage(
      title: '#${widget.topicName}#',
      body: FrostedRefresh(
        topInset: pageTopInset(context),
        onRefresh: () => _load(refresh: true),
        child: _loading && _threads.isEmpty
            ? const FrostedLoading(label: '加载话题中...')
            : _error != null && _threads.isEmpty
                ? FrostedEmpty(
                    title: '加载话题失败',
                    message: _error,
                    icon: FrostedGlyphs.flame,
                    action: FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('重试'),
                    ),
                  )
                : ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      14,
                      pageTopInset(context) + 8,
                      14,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    children: [
                      if (_detail != null) ...[
                        FrostedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${_detail!.topicName}#',
                                style: AppTextStyle.title3
                                    .of(context)
                                    .copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (_detail!.topicDesc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _detail!.topicDesc,
                                  style: AppTextStyle.subheadline
                                      .of(context)
                                      .copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                              if (_detail!.discussNum > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '${formatCount(_detail!.discussNum)} 次讨论',
                                  style: AppTextStyle.caption1
                                      .of(context)
                                      .copyWith(color: scheme.primary),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_threads.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: FrostedEmpty(
                            title: '暂无相关帖子',
                            icon: FrostedGlyphs.flame,
                          ),
                        )
                      else
                        for (var i = 0; i < _threads.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          ThreadCard(
                            key: ValueKey('topic-${_threads[i].effectiveId}'),
                            thread: _threads[i],
                            onTap: () => openThread(
                              context,
                              threadId: _threads[i].effectiveId,
                              forumId: _threads[i].forumId,
                              forumName: _threads[i].forumName,
                              initialTitle: _threads[i].displayTitle,
                            ),
                            onForumTap: () =>
                                openForum(context, _threads[i].forumName),
                            onImageTap: (images, index) => openImageViewer(
                              context,
                              images: images,
                              initialIndex: index,
                            ),
                            onCommentTap: () => openThread(
                              context,
                              threadId: _threads[i].effectiveId,
                              forumId: _threads[i].forumId,
                              forumName: _threads[i].forumName,
                              initialTitle: _threads[i].displayTitle,
                              focusReplies: true,
                            ),
                          ),
                        ],
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: FrostedLoading(),
                        ),
                    ],
                  ),
      ),
    );
  }
}
