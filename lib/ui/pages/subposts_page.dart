import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../core/html_text.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/glyphs.dart';
import '../widgets/post_tile.dart';
import '../widgets/press_scale.dart';
import '../widgets/refresh.dart';
import '../widgets/subpost_tile.dart';

/// 楼中楼详情页（含内联快捷回复输入栏）。
class SubPostsPage extends StatefulWidget {
  const SubPostsPage({
    super.key,
    required this.threadId,
    required this.postId,
    this.forumId = 0,
    this.forumName = '',
    this.lzUserId = 0,
    this.subPostId = 0,
    this.tbs = '',
    this.initialPost,
  });

  final int threadId;
  final int postId;
  final int forumId;
  final String forumName;
  final int lzUserId;
  final int subPostId;
  final String tbs;
  final TiebaPost? initialPost;

  @override
  State<SubPostsPage> createState() => _SubPostsPageState();
}

class _SubPostsPageState extends State<SubPostsPage> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();

  TiebaPost? _parentPost;
  List<TiebaSubPost> _subPosts = [];
  TiebaPageInfo _pageInfo = const TiebaPageInfo();
  int _page = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;
  String _tbs = '';
  String? _error;

  /// 下一页失败：底部显示重试入口，避免停在第一批回复上没有任何提示。
  String? _loadMoreError;

  TiebaSubPost? _replyTarget;

  @override
  void initState() {
    super.initState();
    _parentPost = widget.initialPost;
    _tbs = widget.tbs;
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load(refresh: true));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  /// `pb/floor` 的 `has_more` 常年回 0，只有 `total_page` 是准的（例如 99 页）；
  /// 只看 `has_more` 会让楼中楼永远停在前 30 条。
  bool get _hasMore => _pageInfo.hasMoreAfter(_page);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset < _scroll.position.maxScrollExtent - 300) return;
    if (_loading || _loadingMore || _loadMoreError != null) return;
    if (!_hasMore) return;
    unawaited(_load(refresh: false));
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = _subPosts.isEmpty;
        _error = null;
        _loadMoreError = null;
      });
    } else {
      setState(() {
        _loadingMore = true;
        _loadMoreError = null;
      });
    }

    try {
      final nextPage = refresh ? 1 : _page + 1;
      final res = await context.read<TiebaRepo>().getSubPosts(
        threadId: widget.threadId,
        postId: widget.postId,
        subPostId: refresh ? widget.subPostId : 0,
        page: nextPage,
        forumId: widget.forumId,
      );
      if (!mounted) return;
      setState(() {
        if (res.post != null) _parentPost = res.post;
        if (res.tbs.isNotEmpty) _tbs = res.tbs;
        _pageInfo = res.page;
        if (refresh) {
          _subPosts = res.subPosts;
        } else {
          final seen = _subPosts.map((e) => e.id).toSet();
          _subPosts = [
            ..._subPosts,
            for (final s in res.subPosts)
              if (seen.add(s.id)) s,
          ];
        }
        // 至少推进到刚请求的那一页：服务端回显旧页码时不至于反复拉同一页。
        final echoed = res.page.currentPage;
        _page = refresh
            ? (echoed > 0 ? echoed : nextPage)
            : (echoed > nextPage ? echoed : nextPage);
        _loading = false;
        _loadingMore = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        if (!refresh) _loadMoreError = _error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _sendInlineReply() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await ensureLoggedIn(context, reason: '登录后即可回复楼中楼')) return;
    if (!mounted) return;

    setState(() => _sending = true);
    try {
      final target = _replyTarget;
      final finalContent = target != null
          ? '回复 ${target.author.displayName} :$text'
          : text;
      await context.read<TiebaRepo>().reply(
        forumId: widget.forumId,
        forumName: widget.forumName,
        threadId: widget.threadId,
        content: finalContent,
        quotePostId: widget.postId,
        subPostId: target?.id,
        replyUid: target?.author.id ?? _parentPost?.author.id,
        tbsOverride: _tbs,
      );
      if (!mounted) return;
      _input.clear();
      setState(() {
        _sending = false;
        _replyTarget = null;
      });
      showFrostedToast(context, '回复成功');
      unawaited(_load(refresh: true));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      await handleWriteFailure(context, e);
    }
  }

  Future<void> _toggleSubAgree(int idx) async {
    if (!await ensureLoggedIn(context, reason: '登录后即可点赞')) return;
    if (!mounted) return;
    final sub = _subPosts[idx];
    final nextAgree = !sub.agree.isAgreed;
    setState(() => _subPosts[idx] = sub.copyWith(agree: sub.agree.toggleAgree()));
    try {
      await context.read<TiebaRepo>().opAgree(
        threadId: widget.threadId,
        postId: sub.id,
        agree: nextAgree,
        objType: 2,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _subPosts[idx] = sub);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  /// 长按楼中楼复制这条回复的纯文字；点按仍是「回复此人」。
  Future<void> _copySubPost(TiebaSubPost sub) =>
      showCopyTextDialog(context, richTextToPlainText(sub.content));

  /// 下一页失败时的手动重试入口。
  Widget _buildLoadMoreRetry(BuildContext context, ColorScheme scheme) {
    return Center(
      child: PressScale(
        scale: 0.98,
        child: FrostedTapSurface(
          onPressed: () => unawaited(_load(refresh: false)),
          pill: true,
          fill: context.surfaceLevel.next.colorOf(scheme),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlyphIcon(
                  FrostedGlyphs.refresh,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '加载失败，点击重试',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floorNum = _parentPost?.floor ?? 0;
    final title = floorNum > 0 ? '$floorNum楼的回复' : '楼中楼';
    final scheme = context.colorScheme;
    final settings = context.watch<FrostedSettings>();
    final merged = settings.commentStyle == CommentStyle.merged;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return FrostedPage(
      title: title,
      resizeToAvoidBottomInset: true,
      foot: FrostedBlurBar(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 10, bottom + 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: InputDecoration(
                    hintText: _replyTarget != null
                        ? '回复 ${_replyTarget!.author.displayName}...'
                        : '回复楼层...',
                  ),
                  onSubmitted: (_) => _sendInlineReply(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _sendInlineReply,
                tooltip: '发送',
                icon: _sending
                    ? const ActivityIndicator(size: 18)
                    : GlyphIcon(
                        FrostedGlyphs.send,
                        size: 20,
                        color: scheme.primary,
                      ),
              ),
            ],
          ),
        ),
      ),
      body: FrostedRefresh(
        topInset: pageTopInset(context),
        onRefresh: () => _load(refresh: true),
        child: _loading && _subPosts.isEmpty
            ? const FrostedLoading(label: '加载楼中楼...')
            : _error != null && _subPosts.isEmpty
                ? FrostedEmpty(
                    title: '加载失败',
                    message: _error,
                    icon: FrostedGlyphs.comment,
                    action: FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('重试'),
                    ),
                  )
                : CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          pageTopInset(context) + 8,
                          14,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_parentPost != null) ...[
                                PostTile(
                                  post: _parentPost!.copyWith(
                                    subPosts: const [],
                                  ),
                                  lzUserId: widget.lzUserId,
                                  isFirstFloor: true,
                                  onAuthorTap: _parentPost!.author.id > 0
                                      ? () => openUserProfile(
                                          context,
                                          uid: _parentPost!.author.id,
                                          portrait: _parentPost!.author.portrait,
                                          initialName:
                                              _parentPost!.author.displayName,
                                        )
                                      : null,
                                  onLinkTap: (url) =>
                                      openTiebaUrl(context, url),
                                  onImageTap: (imgs, i) => openImageViewer(
                                    context,
                                    images: imgs,
                                    initialIndex: i,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  '共 ${_pageInfo.totalCount > 0 ? _pageInfo.totalCount : _subPosts.length} 条楼中楼',
                                  style: AppTextStyle.footnote
                                      .of(context)
                                      .copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_subPosts.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 36,
                            ),
                            child: FrostedEmpty(
                              title: '暂无楼中楼回复',
                              icon: FrostedGlyphs.comment,
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          sliver: SliverList.separated(
                            itemCount: _subPosts.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: merged ? 16 : 8),
                            itemBuilder: (context, i) {
                              final sub = _subPosts[i];
                              return SubPostTile(
                                key: ValueKey('sub-${sub.id}'),
                                subPost: sub,
                                lzUserId: widget.lzUserId,
                                onAuthorTap: sub.author.id > 0
                                    ? () => openUserProfile(
                                        context,
                                        uid: sub.author.id,
                                        portrait: sub.author.portrait,
                                        initialName: sub.author.displayName,
                                      )
                                    : null,
                                onReplyTap: () =>
                                    setState(() => _replyTarget = sub),
                                onLongPress: () => _copySubPost(sub),
                                onAgreeTap: () => _toggleSubAgree(i),
                                onLinkTap: (url) => openTiebaUrl(context, url),
                                onAtTap: (uid, name) => openUserProfile(
                                  context,
                                  uid: uid,
                                  initialName: name,
                                ),
                                onImageTap: (imgs, idx) => openImageViewer(
                                  context,
                                  images: imgs,
                                  initialIndex: idx,
                                ),
                              );
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            14,
                            _loadingMore ? 16 : 8,
                            14,
                            bottom + 96,
                          ),
                          child: _loadingMore
                              ? const FrostedLoading()
                              : _loadMoreError != null
                              ? _buildLoadMoreRetry(context, scheme)
                              : (!_hasMore && _subPosts.isNotEmpty)
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '— 到底了 —',
                                      style: AppTextStyle.caption1
                                          .of(context)
                                          .copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
