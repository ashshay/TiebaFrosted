import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/local_db.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../routes.dart';
import '../widgets/common.dart';
import '../widgets/forum_card.dart';
import '../widgets/glyphs.dart';
import '../widgets/segmented_capsule.dart';
import 'search_forum_page.dart';
import 'search_thread_page.dart';
import 'search_user_page.dart';

/// 搜索入口页：实时搜索建议 + SQLite 历史记录 + 搜吧 / 搜帖 / 搜人 综合切换。
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery = '',
    this.forumName,
  });

  final String initialQuery;
  final String? forumName;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _sugTimer;
  List<String> _history = [];
  SearchSugResult? _sug;
  String _submitted = '';
  int _tab = 0; // 0=搜吧, 1=搜帖, 2=搜人

  @override
  void initState() {
    super.initState();
    if (widget.forumName != null && widget.forumName!.isNotEmpty) {
      _tab = 1;
    }
    if (widget.initialQuery.trim().isNotEmpty) {
      _submitted = widget.initialQuery.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadHistory());
    });
  }

  @override
  void dispose() {
    _sugTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await context.read<LocalDb>().getSearchHistory();
    if (mounted) setState(() => _history = list);
  }

  void _onChanged(String val) {
    final q = val.trim();
    if (q.isEmpty) {
      setState(() {
        _submitted = '';
        _sug = null;
      });
      return;
    }
    _sugTimer?.cancel();
    _sugTimer = Timer(const Duration(milliseconds: 280), () async {
      try {
        final res = await context.read<TiebaRepo>().getSearchSuggestions(q);
        if (mounted && _controller.text.trim() == q && _submitted.isEmpty) {
          setState(() => _sug = res);
        }
      } on Object {
        // 联想失败忽略
      }
    });
  }

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    _controller.text = q;
    await context.read<LocalDb>().addSearchHistory(q);
    await _loadHistory();
    if (mounted) {
      setState(() {
        _submitted = q;
        _sug = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final inForum = widget.forumName != null && widget.forumName!.isNotEmpty;

    return PrismScaffold(
      bar: FrostedAppBar(
        leading: const FrostedBackButton(),
        title: SearchField(
          controller: _controller,
          autofocus: _submitted.isEmpty,
          hintText: inForum ? '搜索 ${widget.forumName}吧 内帖子' : '搜贴吧、帖子、吧友',
          onChanged: _onChanged,
          onSubmitted: () => _submit(_controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => _submit(_controller.text),
            child: const Text('搜索'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: pageTopInset(context)),
        child: _submitted.isEmpty
            ? _buildDiscovery(context, scheme)
            : Column(
                children: [
                  if (!inForum)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                      child: FrostedSegmentedControl<int>(
                        value: _tab,
                        onChanged: (v) => setState(() => _tab = v),
                        segments: const [
                          (0, '贴吧'),
                          (1, '帖子'),
                          (2, '吧友'),
                        ],
                      ),
                    ),
                  Expanded(
                    child: switch (_tab) {
                      0 => SearchForumView(
                          key: ValueKey('sf-$_submitted'),
                          keyword: _submitted,
                        ),
                      1 => SearchThreadView(
                          key: ValueKey('st-$_submitted-${widget.forumName ?? ""}'),
                          keyword: _submitted,
                          forumName: widget.forumName,
                        ),
                      _ => SearchUserView(
                          key: ValueKey('su-$_submitted'),
                          keyword: _submitted,
                        ),
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDiscovery(BuildContext context, ColorScheme scheme) {
    final sug = _sug;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: [
        if (sug?.forumCard != null) ...[
          ForumCard(
            name: sug!.forumCard!.forumName,
            avatar: sug.forumCard!.avatar,
            subtitle: sug.forumCard!.slogan,
            onTap: () => openForum(context, sug.forumCard!.forumName),
          ),
          const SizedBox(height: 10),
        ],
        if (sug != null && sug.suggestions.isNotEmpty) ...[
          FrostedSettingsGroup(
            children: [
              for (final s in sug.suggestions)
                FrostedListRow(
                  leading: const GlyphIcon(FrostedGlyphs.search, size: 17),
                  title: Text(s),
                  onPressed: () => _submit(s),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (_history.isNotEmpty) ...[
          Row(
            children: [
              Text(
                '搜索历史',
                style: AppTextStyle.footnote
                    .of(context)
                    .copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await context.read<LocalDb>().clearSearchHistory();
                  await _loadHistory();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kw in _history)
                FrostedTapSurface(
                  onPressed: () => _submit(kw),
                  onLongPress: () async {
                    await context.read<LocalDb>().deleteSearchHistory(kw);
                    await _loadHistory();
                  },
                  pill: true,
                  fill: SurfaceLevel.card.colorOf(scheme),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Text(
                      kw,
                      style: AppTextStyle.footnote.of(context),
                    ),
                  ),
                ),
            ],
          ),
        ] else if (sug == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: FrostedEmpty(
              title: '输入关键词开始搜索',
              message: '支持直接搜索贴吧、全吧帖子与贴吧用户',
              icon: FrostedGlyphs.search,
            ),
          ),
      ],
    );
  }
}
