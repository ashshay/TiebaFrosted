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
import '../widgets/rich_text.dart';

/// TA 的帖子 / 回复列表页。
class UserPostPage extends StatefulWidget {
  const UserPostPage({
    super.key,
    required this.uid,
    this.title = '帖子与回复',
    this.initialThreads = true,
  });

  final int uid;
  final String title;
  final bool initialThreads;

  @override
  State<UserPostPage> createState() => _UserPostPageState();
}

class _UserPostPageState extends State<UserPostPage> {
  final ScrollController _scroll = ScrollController();
  late bool _isThread = widget.initialThreads;
  List<UserPostItem> _items = [];
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
      final list = await context.read<TiebaRepo>().getUserPosts(
        uid: widget.uid,
        page: nextPage,
        isThread: _isThread,
      );
      if (!mounted) return;
      setState(() {
        _items = refresh ? list : [..._items, ...list];
        _page = nextPage;
        _hasMore = list.length >= 10;
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
      title: widget.title,
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: SegmentedControl<bool>(
                value: _isThread,
                onChanged: (v) {
                  if (v == _isThread) return;
                  setState(() {
                    _isThread = v;
                    _items = [];
                  });
                  unawaited(_load(refresh: true));
                },
                segments: const [
                  (true, '主题帖'),
                  (false, '回复'),
                ],
              ),
            ),
            Expanded(
              child: FrostedRefresh(
                onRefresh: () => _load(refresh: true),
                child: _loading && _items.isEmpty
                    ? const FrostedLoading(label: '加载中...')
                    : _error != null && _items.isEmpty
                        ? FrostedEmpty(
                            title: '加载失败',
                            message: _error,
                            icon: FrostedGlyphs.comment,
                            action: FilledButton(
                              onPressed: () => _load(refresh: true),
                              child: const Text('重试'),
                            ),
                          )
                        : _items.isEmpty
                            ? FrostedEmpty(
                                title: _isThread ? '暂无主题帖' : '暂无回复',
                                icon: FrostedGlyphs.comment,
                              )
                            : ListView.separated(
                                controller: _scroll,
                                padding: EdgeInsets.fromLTRB(
                                  14,
                                  4,
                                  14,
                                  MediaQuery.paddingOf(context).bottom + 24,
                                ),
                                itemCount:
                                    _items.length + (_loadingMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  if (idx >= _items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
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
                                      postId: item.postId > 0
                                          ? item.postId
                                          : null,
                                      initialTitle: item.title,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title.isNotEmpty
                                              ? item.title
                                              : item.abstractText,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyle.headline
                                              .of(context)
                                              .copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (item.abstractText.isNotEmpty &&
                                            item.abstractText !=
                                                item.title) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            item.abstractText,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyle.subheadline
                                                .of(context)
                                                .copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                        if (item.images.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          TiebaImageGrid(
                                            images: item.images,
                                            maxDisplay: 3,
                                            onTap: (i) => openImageViewer(
                                              context,
                                              images: item.images,
                                              initialIndex: i,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          joinMeta([
                                            if (item.forumName.isNotEmpty)
                                              '${item.forumName}吧',
                                            if (item.createTime > 0)
                                              formatTiebaTime(item.createTime),
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
            ),
          ],
        ),
      ),
    );
  }
}
