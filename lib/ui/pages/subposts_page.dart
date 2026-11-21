import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/post_tile.dart';
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

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset >= _scroll.position.maxScrollExtent - 300 &&
        _pageInfo.hasMore &&
        !_loading &&
        !_loadingMore) {
      unawaited(_load(refresh: false));
    }
  }

  Future<void> _load({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _loading = _subPosts.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
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
        _page = nextPage;
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
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
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

  @override
  Widget build(BuildContext context) {
    final floorNum = _parentPost?.floor ?? 0;
    final title = floorNum > 0 ? '$floorNum楼的回复' : '楼中楼';
    final scheme = context.colorScheme;
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
                : ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      14,
                      pageTopInset(context) + 8,
                      14,
                      bottom + 96,
                    ),
                    children: [
                      if (_parentPost != null) ...[
                        PostTile(
                          post: _parentPost!.copyWith(subPosts: const []),
                          lzUserId: widget.lzUserId,
                          isFirstFloor: true,
                          onAuthorTap: _parentPost!.author.id > 0
                              ? () => openUserProfile(
                                  context,
                                  uid: _parentPost!.author.id,
                                  portrait: _parentPost!.author.portrait,
                                  initialName: _parentPost!.author.displayName,
                                )
                              : null,
                          onLinkTap: (url) => openTiebaUrl(context, url),
                          onImageTap: (imgs, i) => openImageViewer(
                            context,
                            images: imgs,
                            initialIndex: i,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
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
                      if (_subPosts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 36),
                          child: FrostedEmpty(
                            title: '暂无楼中楼回复',
                            icon: FrostedGlyphs.comment,
                          ),
                        )
                      else
                        for (var i = 0; i < _subPosts.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          SubPostTile(
                            key: ValueKey('sub-${_subPosts[i].id}'),
                            subPost: _subPosts[i],
                            lzUserId: widget.lzUserId,
                            onAuthorTap: _subPosts[i].author.id > 0
                                ? () => openUserProfile(
                                    context,
                                    uid: _subPosts[i].author.id,
                                    portrait: _subPosts[i].author.portrait,
                                    initialName:
                                        _subPosts[i].author.displayName,
                                  )
                                : null,
                            onReplyTap: () =>
                                setState(() => _replyTarget = _subPosts[i]),
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
