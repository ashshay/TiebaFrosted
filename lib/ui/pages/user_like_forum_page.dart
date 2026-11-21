import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/forum_card.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';

/// TA 关注的吧列表页。
class UserLikeForumPage extends StatefulWidget {
  const UserLikeForumPage({
    super.key,
    required this.uid,
    this.title = '关注的吧',
  });

  final int uid;
  final String title;

  @override
  State<UserLikeForumPage> createState() => _UserLikeForumPageState();
}

class _UserLikeForumPageState extends State<UserLikeForumPage> {
  final ScrollController _scroll = ScrollController();
  List<FollowedForum> _items = [];
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
      final res = await context.read<TiebaRepo>().getUserLikeForums(
        uid: widget.uid,
        page: nextPage,
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
    return FrostedPage(
      title: widget.title,
      body: FrostedRefresh(
        topInset: pageTopInset(context),
        onRefresh: () => _load(refresh: true),
        child: _loading && _items.isEmpty
            ? const FrostedLoading(label: '加载关注的吧...')
            : _error != null && _items.isEmpty
                ? FrostedEmpty(
                    title: '加载失败',
                    message: _error,
                    icon: FrostedGlyphs.forum,
                    action: FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('重试'),
                    ),
                  )
                : _items.isEmpty
                    ? const FrostedEmpty(
                        title: '暂无关注的贴吧',
                        icon: FrostedGlyphs.forum,
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
                          final f = _items[idx];
                          return ForumCard(
                            name: f.forumName,
                            avatar: f.avatar,
                            subtitle: f.levelName,
                            levelId: f.levelId,
                            isSigned: f.isSign,
                            onTap: () => openForum(
                              context,
                              f.forumName,
                              initialAvatar: f.avatar,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
