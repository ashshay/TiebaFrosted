import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';
import '../widgets/user_list.dart';

/// 关注列表页。
class FollowListPage extends StatefulWidget {
  const FollowListPage({super.key, this.uid, this.title = '关注列表'});

  final int? uid;
  final String title;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final ScrollController _scroll = ScrollController();
  List<TiebaUser> _users = [];
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
        _loading = _users.isEmpty;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final nextPage = refresh ? 1 : _page + 1;
      final res = await context.read<TiebaRepo>().getFollowList(
        uid: widget.uid,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _users = refresh ? res.items : [..._users, ...res.items];
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
        child: _loading && _users.isEmpty
            ? const FrostedLoading(label: '加载关注列表...')
            : _error != null && _users.isEmpty
                ? FrostedEmpty(
                    title: '加载失败',
                    message: _error,
                    icon: FrostedGlyphs.follow,
                    action: FilledButton(
                      onPressed: () => _load(refresh: true),
                      child: const Text('重试'),
                    ),
                  )
                : _users.isEmpty
                    ? const FrostedEmpty(
                        title: '暂无关注的用户',
                        icon: FrostedGlyphs.follow,
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(
                          14,
                          pageTopInset(context) + 8,
                          14,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        itemCount: _users.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          if (idx >= _users.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: FrostedLoading(),
                            );
                          }
                          final u = _users[idx];
                          return UserListTile(
                            name: u.displayName,
                            portrait: u.portrait,
                            subtitle: u.intro,
                            onTap: () => openUserProfile(
                              context,
                              uid: u.id > 0 ? u.id : null,
                              portrait: u.portrait,
                              initialName: u.displayName,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
