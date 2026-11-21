import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/store.dart';
import '../chrome.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';

/// 消息通知中心：回复我的 / @我的。
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ScrollController _scroll = ScrollController();
  int _tab = 0; // 0=回复我的, 1=@我的
  List<NotificationItem> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<FrostedStore>().isLoggedIn) {
        unawaited(_load(refresh: true));
      }
    });
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
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }
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
      final res = _tab == 0
          ? await repo.getReplyMe(page: nextPage)
          : await repo.getAtMe(page: nextPage);
      if (!mounted) return;
      setState(() {
        _items = refresh ? res.items : [..._items, ...res.items];
        _page = nextPage;
        _hasMore = res.hasMore;
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
    final chrome = context.watch<ChromeController>();
    final store = context.watch<FrostedStore>();
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);

    return PrismScaffold(
      bar: FrostedAppBar(
        hidden: chrome.hidden,
        title: SizedBox(
          width: 176,
          child: SegmentedControl<int>(
            value: _tab,
            onChanged: (v) {
              if (v == _tab) return;
              setState(() {
                _tab = v;
                _items = [];
                _page = 1;
                _hasMore = false;
              });
              unawaited(_load(refresh: true));
            },
            segments: const [
              (0, '回复我'),
              (1, '@提到'),
            ],
          ),
        ),
      ),
      body: ChromeScrollListener(
        onHiddenChanged: chrome.setHidden,
        child: FrostedRefresh(
          topInset: top,
          onRefresh: () => _load(refresh: true),
          child: !store.isLoggedIn
              ? FrostedEmpty(
                  title: '登录后查看消息通知',
                  message: '查看回复我的帖子、楼中楼与 @提及',
                  icon: FrostedGlyphs.bell,
                  action: FilledButton(
                    onPressed: () => openLogin(context),
                    child: const Text('登录贴吧'),
                  ),
                )
              : _loading && _items.isEmpty
                  ? const FrostedLoading(label: '加载消息中...')
                  : _error != null && _items.isEmpty
                      ? FrostedEmpty(
                          title: '加载消息失败',
                          message: _error,
                          icon: FrostedGlyphs.bell,
                          action: FilledButton(
                            onPressed: () => _load(refresh: true),
                            child: const Text('重试'),
                          ),
                        )
                      : _items.isEmpty
                          ? const FrostedEmpty(
                              title: '暂无新消息',
                              message: '有新回复或 @提醒时会显示在这里',
                              icon: FrostedGlyphs.bell,
                            )
                          : ListView.separated(
                              controller: _scroll,
                              padding: EdgeInsets.fromLTRB(
                                14,
                                top + 8,
                                14,
                                bottom,
                              ),
                              itemCount:
                                  _items.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                if (idx >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: FrostedLoading(),
                                  );
                                }
                                final item = _items[idx];
                                return _NotificationCard(
                                  item: item,
                                  onTap: () => openThread(
                                    context,
                                    threadId: item.threadId,
                                    forumName: item.forumName,
                                    postId: item.postId > 0
                                        ? item.postId
                                        : null,
                                    initialTitle: item.title,
                                  ),
                                );
                              },
                            ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return FrostedCard(
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(url: item.userPortrait, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.userName.isNotEmpty ? item.userName : '贴吧用户',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.subheadline
                          .of(context)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      joinMeta([
                        if (item.forumName.isNotEmpty) '${item.forumName}吧',
                        if (item.time > 0) formatTiebaTime(item.time),
                      ]),
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.content,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(color: scheme.onSurface),
            ),
          ],
          if (item.quoteContent.isNotEmpty || item.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (innerContext) {
                final blockLevel = innerContext.surfaceLevel.next;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    color: blockLevel.colorOf(scheme),
                    shape: AppShape.md,
                  ),
                  child: Text(
                    item.quoteContent.isNotEmpty
                        ? item.quoteContent
                        : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.footnote
                        .of(innerContext)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
