import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/native_channels.dart';
import '../../data/repo.dart';
import '../../data/settings.dart';
import '../chrome.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/post_tile.dart';
import '../widgets/press_scale.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';
import '../widgets/skeleton.dart';

/// 帖子详情页（核心）：主楼 + 楼层列表 + 只看楼主 + 排序切换 + 投票 + 收藏/点赞 + 底部回复栏。
class ThreadPage extends StatefulWidget {
  const ThreadPage({
    super.key,
    required this.threadId,
    this.forumId = 0,
    this.forumName = '',
    this.forumAvatar = '',
    this.initialPostId,
    this.initialSubPostId,
    this.initialTitle = '',
    this.fromStore = false,
    this.focusReplies = false,
  });

  final int threadId;
  final int forumId;
  final String forumName;

  /// 上一页已知的吧头像，进来就能画出来，不必等帖内接口返回。
  final String forumAvatar;
  final int? initialPostId;
  final int? initialSubPostId;
  final String initialTitle;
  final bool fromStore;

  /// 首屏加载完直接滚到回复区（信息流点「评论」进来时用）。
  final bool focusReplies;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _repliesKey = GlobalKey();

  TiebaThread _thread = const TiebaThread(id: 0);
  TiebaForum _forum = const TiebaForum();

  /// 本页自己的顶栏/底栏收起状态。
  ///
  /// 不复用全局 [ChromeController]：那样滚动详情页会把主壳底栏一起藏掉，
  /// 返回时还得靠 dispose 复位，容易留下脏状态。
  bool _barHidden = false;
  TiebaPageInfo _pageInfo = const TiebaPageInfo();
  TiebaPost? _firstFloor;
  List<TiebaPost> _posts = [];
  String _tbs = '';

  int _sortType = 0; // 0=正序, 1=倒序, 2=热门
  bool _seeLz = false;
  int _currentPage = 1;

  /// 只自动定位一次，之后用户自己滚。
  bool _focusedReplies = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _thread = TiebaThread(
      id: widget.threadId,
      threadId: widget.threadId,
      title: widget.initialTitle,
      forumId: widget.forumId,
      forumName: widget.forumName,
    );
    _forum = TiebaForum(id: widget.forumId, name: widget.forumName);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load(page: 1, postId: widget.initialPostId ?? 0, reset: true));
    });
  }

  /// 首屏渲染后把回复区顶到可视区顶部。
  ///
  /// 用 [_repliesKey] 的偏移量而不是估算高度：主楼长短差别很大，估算会飘。
  void _scrollToReplies() {
    final ctx = _repliesKey.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox) return;
    final target = _scroll.offset + box.localToGlobal(Offset.zero).dy -
        pageTopInset(context) - 8;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _isDesc => _sortType == 1;

  /// 倒序是从最后一页往前翻，所以「还有没有下一批」得看剩下几页可以往回走，
  /// 而不是服务端在正序意义下报的 hasMore。
  bool get _hasMoreInDirection =>
      _isDesc ? _currentPage > 1 : _pageInfo.hasMore;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset < _scroll.position.maxScrollExtent - 360) return;
    if (_loading || _loadingMore || !_hasMoreInDirection) return;
    unawaited(
      _load(page: _isDesc ? _currentPage - 1 : _currentPage + 1, reset: false),
    );
  }

  Future<void> _load({
    required int page,
    int postId = 0,
    required bool reset,
  }) async {
    if (reset) {
      setState(() {
        _loading = _posts.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res = await context.read<TiebaRepo>().getThreadPage(
        threadId: widget.threadId,
        page: page,
        postId: postId,
        seeLz: _seeLz,
        sortType: _sortType,
        forumId: _forum.id > 0 ? _forum.id : widget.forumId,
        mark: widget.fromStore,
      );
      if (!mounted) return;
      final replies = res.posts.where((p) => p.floor != 1).toList();
      setState(() {
        if (res.thread.effectiveId > 0) _thread = res.thread;
        if (res.forum.name.isNotEmpty) _forum = res.forum;
        _pageInfo = res.page;
        if (res.tbs.isNotEmpty) _tbs = res.tbs;
        if (res.firstFloorPost != null) _firstFloor = res.firstFloorPost;
        if (reset) {
          _posts = replies;
        } else {
          final seen = _posts.map((p) => p.id).toSet();
          _posts = [
            ..._posts,
            for (final p in replies)
              if (seen.add(p.id)) p,
          ];
        }
        _currentPage = res.page.currentPage > 0 ? res.page.currentPage : page;
        _loading = false;
        _loadingMore = false;
      });
      if (reset && widget.focusReplies && !_focusedReplies) {
        _focusedReplies = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToReplies();
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  int get _lzUserId => _firstFloor?.author.id ?? _thread.author.id;
  int get _effectiveForumId => _forum.id > 0 ? _forum.id : _thread.forumId;
  String get _effectiveForumName =>
      _forum.name.isNotEmpty ? _forum.name : _thread.forumName;

  /// 吧头像优先取帖内拉到的 `TiebaForum`，其次用上一页带过来的，最后退回帖子自带的
  /// `forumAvatar`；全空时胶囊显示占位块。
  String get _effectiveForumAvatar {
    if (_forum.avatar.isNotEmpty) return _forum.avatar;
    if (widget.forumAvatar.isNotEmpty) return widget.forumAvatar;
    return _thread.forumAvatar;
  }

  Future<void> _toggleCollect() async {
    if (!await ensureLoggedIn(context, reason: '登录后即可收藏帖子')) return;
    if (!mounted) return;
    final nextCollect = !_thread.isCollected;
    final prev = _thread;
    setState(() {
      _thread = _thread.copyWith(collectStatus: nextCollect ? 1 : 0);
    });
    HapticFeedback.lightImpact();
    try {
      await context.read<TiebaRepo>().toggleThreadStore(
        threadId: widget.threadId,
        postId: _firstFloor?.id ?? _thread.firstPostId,
        forumId: _effectiveForumId,
        collect: nextCollect,
      );
      if (mounted) {
        showFrostedToast(context, nextCollect ? '已收藏' : '已取消收藏');
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _thread = prev);
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  Future<void> _togglePostAgree(TiebaPost post, {required bool isFirst}) async {
    if (!await ensureLoggedIn(context, reason: '登录后即可点赞')) return;
    if (!mounted) return;
    final nextAgree = !post.agree.isAgreed;
    final updated = post.copyWith(agree: post.agree.toggleAgree());
    setState(() {
      if (isFirst) {
        _firstFloor = updated;
      } else {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx >= 0) _posts[idx] = updated;
      }
    });
    try {
      await context.read<TiebaRepo>().opAgree(
        threadId: widget.threadId,
        postId: post.id,
        agree: nextAgree,
        objType: isFirst ? 3 : 1,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        if (isFirst) {
          _firstFloor = post;
        } else {
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx >= 0) _posts[idx] = post;
        }
      });
      showFrostedToast(context, cleanError(e), level: BannerLevel.error);
    }
  }

  Future<void> _openReplyEditor({TiebaPost? quotePost}) async {
    if (!await ensureLoggedIn(context, reason: '登录后即可回复帖子')) return;
    if (!mounted) return;
    final ok = await openReply(
      context,
      forumId: _effectiveForumId,
      forumName: _effectiveForumName,
      threadId: widget.threadId,
      quotePostId: quotePost?.id,
      replyUid: quotePost?.author.id,
      replyUserName: quotePost?.author.displayName,
      tbs: _tbs,
    );
    if (ok == true && mounted) {
      unawaited(_load(page: _currentPage, reset: true));
    }
  }

  Future<void> _showThreadActions() async {
    final picked = await showFrostedChoices<String>(
      context,
      title: '帖子操作',
      choices: [
        FrostedChoice(
          value: 'lz',
          label: _seeLz ? '查看全部楼层' : '只看楼主',
          selected: _seeLz,
        ),
        const FrostedChoice(value: 'jump', label: '跳页'),
        if (_effectiveForumName.isNotEmpty)
          FrostedChoice(value: 'forum', label: '进入 $_effectiveForumName吧'),
        const FrostedChoice(value: 'copy', label: '复制链接'),
        const FrostedChoice(value: 'share', label: '分享帖子'),
      ],
    );
    if (picked == null || !mounted) return;
    final url = 'https://tieba.baidu.com/p/${widget.threadId}';
    switch (picked) {
      case 'lz':
        setState(() {
          _seeLz = !_seeLz;
          _posts = [];
        });
        unawaited(_load(page: 1, reset: true));
      case 'jump':
        final total = _pageInfo.effectiveTotalPage;
        final raw = await showFrostedInputDialog(
          context,
          title: '跳转到指定页 (1 - $total)',
          initial: '$_currentPage',
          hint: '输入页码',
        );
        final target = int.tryParse(raw ?? '');
        if (target != null && target >= 1 && target <= total && mounted) {
          setState(() => _posts = []);
          unawaited(_load(page: target, reset: true));
        }
      case 'forum':
        await openForum(context, _effectiveForumName);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) showFrostedToast(context, '已复制链接');
      case 'share':
        await NativeChannels.shareText(
          '${_thread.displayTitle}\n$url',
          subject: _thread.displayTitle,
        );
    }
  }

  Future<void> _showPostActions(TiebaPost post) async {
    final picked = await showFrostedChoices<String>(
      context,
      title: '${post.floor}楼 · ${post.author.displayName}',
      choices: const [
        FrostedChoice(value: 'reply', label: '回复此楼'),
        FrostedChoice(value: 'subposts', label: '查看楼中楼'),
        FrostedChoice(value: 'author', label: '查看作者主页'),
        FrostedChoice(value: 'copy', label: '复制楼层链接'),
      ],
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'reply':
        await _openReplyEditor(quotePost: post);
      case 'subposts':
        await openSubPosts(
          context,
          threadId: widget.threadId,
          postId: post.id,
          forumId: _effectiveForumId,
          forumName: _effectiveForumName,
          lzUserId: _lzUserId,
          tbs: _tbs,
          initialPost: post,
        );
      case 'author':
        if (post.author.id > 0) {
          await openUserProfile(
            context,
            uid: post.author.id,
            portrait: post.author.portrait,
            initialName: post.author.displayName,
          );
        }
      case 'copy':
        final link = 'https://tieba.baidu.com/p/${widget.threadId}?pid=${post.id}';
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) showFrostedToast(context, '已复制楼层链接');
    }
  }

  /// 帖内动作：只看楼主 / 收藏 / 更多。顶栏与回复区顶栏共用同一份。
  List<Widget> _threadActions(ColorScheme scheme) => [
    PressScale(
      scale: 0.92,
      child: IconButton(
        onPressed: () {
          setState(() {
            _seeLz = !_seeLz;
            _posts = [];
          });
          unawaited(_load(page: 1, reset: true));
        },
        tooltip: _seeLz ? '查看全部' : '只看楼主',
        icon: GlyphIcon(
          FrostedGlyphs.person,
          size: 20,
          color: _seeLz ? scheme.primary : scheme.onSurface,
          fill: _seeLz ? 1 : 0,
        ),
      ),
    ),
    PressScale(
      scale: 0.92,
      child: IconButton(
        onPressed: _toggleCollect,
        tooltip: _thread.isCollected ? '取消收藏' : '收藏',
        icon: context.disableAnimations
            ? GlyphIcon(
                FrostedGlyphs.bookmark,
                size: 20,
                color: _thread.isCollected
                    ? scheme.primary
                    : scheme.onSurface,
                fill: _thread.isCollected ? 1 : 0,
              )
            : IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: _thread.isCollected
                      ? scheme.primary
                      : scheme.onSurface,
                ),
                child: AnimatedGlyph(
                  glyph: FrostedGlyphs.bookmark,
                  filled: _thread.isCollected,
                ),
              ),
      ),
    ),
    PressScale(
      scale: 0.92,
      child: IconButton(
        onPressed: _showThreadActions,
        tooltip: '更多',
        icon: const GlyphIcon(FrostedGlyphs.more, size: 20),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final settings = context.watch<FrostedSettings>();
    final title = _effectiveForumName.isNotEmpty
        ? '$_effectiveForumName吧'
        : '帖子详情';

    return FrostedPage(
      title: title,
      centerTitle: true,
      hidden: _barHidden,
      footHidden: _barHidden,
      titleWidget: _ForumTitlePill(
        forumName: _effectiveForumName,
        avatar: _effectiveForumAvatar,
        fallback: title,
        onTap: _effectiveForumName.isEmpty
            ? null
            : () => openForum(
                context,
                _effectiveForumName,
                initialAvatar: _effectiveForumAvatar,
              ),
      ),
      // 收藏 / 只看楼主 / 更多 已下移到回复区那一行；「隐藏回复」时回复区整块不渲染，
      // 动作仍留在顶栏，否则帖内就没有入口了。
      actions: settings.hideReply ? _threadActions(scheme) : const [],
      foot: _BottomReplyBar(
        replyCount: _thread.replyNum,
        currentPage: _currentPage,
        totalPage: _pageInfo.effectiveTotalPage,
        onReplyTap: () => _openReplyEditor(),
        onPageTap: _showThreadActions,
      ),
      body: ChromeScrollListener(
        onHiddenChanged: (hidden) {
          if (mounted && hidden != _barHidden) {
            setState(() => _barHidden = hidden);
          }
        },
        child: FrostedRefresh(
          topInset: pageTopInset(context),
          onRefresh: () => _load(page: 1, reset: true),
          child: _buildBody(context, scheme, settings),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme scheme,
    FrostedSettings settings,
  ) {
    final top = pageTopInset(context);
    if (_loading && _firstFloor == null && _posts.isEmpty) {
      return FeedSkeletonList(topInset: top, count: 4);
    }
    if (_error != null && _firstFloor == null && _posts.isEmpty) {
      return FrostedEmpty(
        title: '加载帖子失败',
        message: _error,
        icon: FrostedGlyphs.forum,
        action: FilledButton(
          onPressed: () => _load(page: 1, reset: true),
          child: const Text('重试'),
        ),
      );
    }

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        14,
        top + 8,
        14,
        MediaQuery.paddingOf(context).bottom + 96,
      ),
      children: [
        if (_firstFloor != null) ...[
          PostTile(
            key: ValueKey('post-1-${_firstFloor!.id}'),
            post: _firstFloor!,
            lzUserId: _lzUserId,
            isFirstFloor: true,
            replyCount: _thread.replyNum,
            // 标题并进主楼正文首行，不再单独占一块。
            leadingTitle: _thread.displayTitle,
            onAuthorTap: _firstFloor!.author.id > 0
                ? () => openUserProfile(
                    context,
                    uid: _firstFloor!.author.id,
                    portrait: _firstFloor!.author.portrait,
                    initialName: _firstFloor!.author.displayName,
                  )
                : null,
            onAgreeTap: () => _togglePostAgree(_firstFloor!, isFirst: true),
            onReplyTap: () => _openReplyEditor(),
            onLinkTap: (url) => openTiebaUrl(context, url),
            onAtTap: (uid, name) =>
                openUserProfile(context, uid: uid, initialName: name),
            onImageTap: (imgs, i) =>
                openImageViewer(context, images: imgs, initialIndex: i),
            onVideoTap: (v) => openVideoPlayer(context, videoUrl: v.videoUrl),
          ),
          const SizedBox(height: 12),
        ],
        if (_thread.poll != null && _thread.poll!.options.isNotEmpty) ...[
          _PollCard(
            poll: _thread.poll!,
            onVote: (optionIds) async {
              if (!await ensureLoggedIn(context, reason: '登录后即可参与投票')) return;
              if (!context.mounted) return;
              final repo = context.read<TiebaRepo>();
              try {
                await repo.votePoll(
                  forumId: _effectiveForumId,
                  threadId: widget.threadId,
                  optionIds: optionIds,
                );
                if (context.mounted) {
                  showFrostedToast(context, '投票成功');
                  unawaited(_load(page: 1, reset: true));
                }
              } on Object catch (e) {
                if (context.mounted) {
                  showFrostedToast(
                    context,
                    cleanError(e),
                    level: BannerLevel.error,
                  );
                }
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        if (!settings.hideReply) ...[
          Row(
            key: _repliesKey,
            children: [
              ..._threadActions(scheme),
              const Spacer(),
              SizedBox(
                width: 176,
                child: SegmentedControl<int>(
                  value: _sortType,
                  onChanged: (v) {
                    if (v == _sortType) return;
                    setState(() {
                      _sortType = v;
                      _posts = [];
                    });
                    if (_scroll.hasClients) _scroll.jumpTo(0);
                    // 倒序从最后一页进，直接就是最新回复；正序/热门从第一页。
                    final last = _pageInfo.effectiveTotalPage;
                    final target = v == 1 && last > 0 ? last : 1;
                    unawaited(_load(page: target, reset: true));
                  },
                  segments: const [
                    (0, '正序'),
                    (1, '倒序'),
                    (2, '热门'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_posts.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: FrostedEmpty(
                title: '还没有回复',
                message: '来做第一个评论的吧友吧',
                icon: FrostedGlyphs.comment,
              ),
            )
          else
            for (var i = 0; i < _posts.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              PostTile(
                key: ValueKey('post-${_posts[i].id}'),
                post: _posts[i],
                lzUserId: _lzUserId,
                onAuthorTap: _posts[i].author.id > 0
                    ? () => openUserProfile(
                        context,
                        uid: _posts[i].author.id,
                        portrait: _posts[i].author.portrait,
                        initialName: _posts[i].author.displayName,
                      )
                    : null,
                onAgreeTap: () => _togglePostAgree(_posts[i], isFirst: false),
                onReplyTap: () => _openReplyEditor(quotePost: _posts[i]),
                onSubPostsTap: () => openSubPosts(
                  context,
                  threadId: widget.threadId,
                  postId: _posts[i].id,
                  forumId: _effectiveForumId,
                  forumName: _effectiveForumName,
                  lzUserId: _lzUserId,
                  tbs: _tbs,
                  initialPost: _posts[i],
                ),
                onMoreTap: () => _showPostActions(_posts[i]),
                onLinkTap: (url) => openTiebaUrl(context, url),
                onAtTap: (uid, name) =>
                    openUserProfile(context, uid: uid, initialName: name),
                onImageTap: (imgs, idx) =>
                    openImageViewer(context, images: imgs, initialIndex: idx),
                onVideoTap: (v) =>
                    openVideoPlayer(context, videoUrl: v.videoUrl),
              ),
            ],
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: FrostedLoading(),
            )
          else if (!_hasMoreInDirection && _posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '— 到底了 —',
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _BottomReplyBar extends StatelessWidget {
  const _BottomReplyBar({
    required this.replyCount,
    required this.currentPage,
    required this.totalPage,
    required this.onReplyTap,
    required this.onPageTap,
  });

  final int replyCount;
  final int currentPage;
  final int totalPage;
  final VoidCallback onReplyTap;
  final VoidCallback onPageTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return FrostedBlurBar(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, bottom + 8),
        child: Row(
          children: [
            Expanded(
              child: FrostedTapSurface(
                onPressed: onReplyTap,
                pill: true,
                fill: SurfaceLevel.card.colorOf(scheme),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    '说点什么...',
                    style: AppTextStyle.subheadline
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FrostedTapSurface(
              onPressed: onPageTap,
              pill: true,
              fill: SurfaceLevel.card.colorOf(scheme),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  '$currentPage / ${totalPage > 0 ? totalPage : 1}',
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollCard extends StatefulWidget {
  const _PollCard({required this.poll, required this.onVote});

  final TiebaPoll poll;
  final Future<void> Function(List<int> optionIds) onVote;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  final Set<int> _selected = {};
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final poll = widget.poll;
    final total = poll.totalPoll > 0 ? poll.totalPoll : poll.totalNum;

    return FrostedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                poll.title.isNotEmpty ? poll.title : '投票',
                style: AppTextStyle.headline
                    .of(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              FrostedTag(label: poll.isMulti ? '多选' : '单选'),
              const Spacer(),
              Text(
                '${formatCount(total)} 票',
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final opt in poll.options) ...[
            Builder(
              builder: (innerContext) {
                final chosen = _selected.contains(opt.id);
                final ratio = total > 0 ? (opt.num / total).clamp(0.0, 1.0) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FrostedTapSurface(
                    onPressed: poll.isPolled || _submitting
                        ? null
                        : () {
                            setState(() {
                              if (poll.isMulti) {
                                if (chosen) {
                                  _selected.remove(opt.id);
                                } else {
                                  _selected.add(opt.id);
                                }
                              } else {
                                _selected
                                  ..clear()
                                  ..add(opt.id);
                              }
                            });
                          },
                    radius: AppCorner.sm,
                    fill: chosen
                        ? scheme.primary.withValues(alpha: 0.16)
                        : innerContext.surfaceLevel.next.colorOf(scheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.text,
                              style: AppTextStyle.subheadline.of(innerContext),
                            ),
                          ),
                          if (poll.isPolled)
                            Text(
                              '${(ratio * 100).round()}% (${opt.num})',
                              style: AppTextStyle.caption1
                                  .of(innerContext)
                                  .copyWith(color: scheme.primary),
                            )
                          else if (chosen)
                            GlyphIcon(
                              Glyphs.check,
                              size: 16,
                              color: scheme.primary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          if (!poll.isPolled)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _selected.isEmpty || _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onVote(_selected.toList());
                        if (mounted) setState(() => _submitting = false);
                      },
                child: Text(_submitting ? '提交中...' : '投票'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 顶栏中央的吧名胶囊：头像 + 吧名，点击进吧。
///
/// 对齐 TiebaLite `ThreadPage` 的 `TopBar`——吧名在那里就是一个带底色的可点胶囊，
/// 而不是纯文本标题，这样「进吧」这件事在页面上有明确入口。
class _ForumTitlePill extends StatelessWidget {
  const _ForumTitlePill({
    required this.forumName,
    required this.avatar,
    required this.fallback,
    this.onTap,
  });

  final String forumName;
  final String avatar;
  final String fallback;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    if (onTap == null) {
      return Text(fallback, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return PressScale(
      scale: 0.95,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(3, 3, 12, 3),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHighest,
            shape: AppShape.full,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RemoteImage(
                url: avatar,
                width: 26,
                height: 26,
                radius: AppCorner.full,
                placeholderColor: scheme.surfaceContainerHigh,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$forumName吧',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.footnote
                      .of(context)
                      .copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
