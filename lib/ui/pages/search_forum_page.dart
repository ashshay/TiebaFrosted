import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/forum_card.dart';
import '../widgets/glyphs.dart';

/// 独立搜吧页（也导出 `SearchForumView` 嵌入搜索主页）。
class SearchForumPage extends StatelessWidget {
  const SearchForumPage({super.key, required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return FrostedPage(
      title: '搜吧：$keyword',
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: SearchForumView(keyword: keyword),
      ),
    );
  }
}

class SearchForumView extends StatefulWidget {
  const SearchForumView({super.key, required this.keyword});

  final String keyword;

  @override
  State<SearchForumView> createState() => _SearchForumViewState();
}

class _SearchForumViewState extends State<SearchForumView> {
  SearchForumItem? _exact;
  List<SearchForumItem> _fuzzy = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<TiebaRepo>().searchForum(widget.keyword);
      if (!mounted) return;
      setState(() {
        _exact = res.exact;
        _fuzzy = res.fuzzy;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const FrostedLoading(label: '搜索贴吧中...');
    if (_error != null) {
      return FrostedEmpty(
        title: '搜索失败',
        message: _error,
        icon: FrostedGlyphs.search,
        action: FilledButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (_exact == null && _fuzzy.isEmpty) {
      return const FrostedEmpty(
        title: '没有找到相关贴吧',
        icon: FrostedGlyphs.forum,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        14,
        4,
        14,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (_exact != null) ...[
          const FrostedSectionTitle('精确匹配'),
          ForumCard(
            name: _exact!.forumName,
            avatar: _exact!.avatar,
            subtitle: joinMeta([
              if (_exact!.concernNum.isNotEmpty) '关注 ${_exact!.concernNum}',
              if (_exact!.postNum.isNotEmpty) '帖子 ${_exact!.postNum}',
              _exact!.slogan,
            ]),
            onTap: () => openForum(
              context,
              _exact!.forumName,
              initialAvatar: _exact!.avatar,
            ),
          ),
        ],
        if (_fuzzy.isNotEmpty) ...[
          const FrostedSectionTitle('相关贴吧'),
          for (var i = 0; i < _fuzzy.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            ForumCard(
              name: _fuzzy[i].forumName,
              avatar: _fuzzy[i].avatar,
              subtitle: joinMeta([
                if (_fuzzy[i].concernNum.isNotEmpty)
                  '关注 ${_fuzzy[i].concernNum}',
                if (_fuzzy[i].postNum.isNotEmpty) '帖子 ${_fuzzy[i].postNum}',
                _fuzzy[i].slogan,
              ]),
              onTap: () => openForum(
                context,
                _fuzzy[i].forumName,
                initialAvatar: _fuzzy[i].avatar,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
