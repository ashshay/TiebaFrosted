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
import '../widgets/user_list.dart';

/// 独立搜人页（也导出 `SearchUserView` 嵌入搜索主页）。
class SearchUserPage extends StatelessWidget {
  const SearchUserPage({super.key, required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return FrostedPage(
      title: '搜吧友：$keyword',
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: SearchUserView(keyword: keyword),
      ),
    );
  }
}

class SearchUserView extends StatefulWidget {
  const SearchUserView({super.key, required this.keyword});

  final String keyword;

  @override
  State<SearchUserView> createState() => _SearchUserViewState();
}

class _SearchUserViewState extends State<SearchUserView> {
  List<SearchUserItem> _items = [];
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
      final list = await context.read<TiebaRepo>().searchUser(widget.keyword);
      if (!mounted) return;
      setState(() {
        _items = list;
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
    if (_loading) return const FrostedLoading(label: '搜索吧友中...');
    if (_error != null) {
      return FrostedEmpty(
        title: '搜索失败',
        message: _error,
        icon: FrostedGlyphs.person,
        action: FilledButton(onPressed: _load, child: const Text('重试')),
      );
    }
    if (_items.isEmpty) {
      return const FrostedEmpty(
        title: '没有找到相关吧友',
        icon: FrostedGlyphs.person,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        14,
        4,
        14,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final u = _items[idx];
        return UserListTile(
          name: u.displayName,
          portrait: u.portrait,
          subtitle: joinMeta([
            if (u.fansNum.isNotEmpty) '粉丝 ${u.fansNum}',
            u.intro,
          ]),
          onTap: () => openUserProfile(
            context,
            uid: u.uid > 0 ? u.uid : null,
            portrait: u.portrait,
            initialName: u.displayName,
          ),
        );
      },
    );
  }
}
