import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../data/store.dart';
import '../../data/tab_cache.dart';
import '../chrome.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';
import '../widgets/refresh.dart';
import '../widgets/remote_image.dart';
import '../widgets/segmented_capsule.dart';

/// 消息通知中心：回复我的 / @我的。
///
/// 两个分栏各自保活并接入本地快照缓存，首次切换不重载，支持下拉与底栏双击回顶刷新。
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotifyTabState {
  final ScrollController scroll = ScrollController();
  List<NotificationItem> items = [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  bool loadedOnce = false;
  int page = 1;
  String? error;

  void dispose() => scroll.dispose();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_NotifyTabState> _states = [_NotifyTabState(), _NotifyTabState()];
  ChromeController? _chrome;
  int _lastNotifyRefresh = 0;
  int _tab = 0; // 0=回复我的, 1=@我的

  String get _accountKey => context.read<FrostedStore>().activeUid ?? 'guest';

  @override
  void initState() {
    super.initState();
    _states[0].scroll.addListener(() => _onScroll(0));
    _states[1].scroll.addListener(() => _onScroll(1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chrome = context.read<ChromeController>();
      _lastNotifyRefresh = _chrome!.notificationsRefreshCount;
      _chrome!.addListener(_onChromeChange);
      if (context.read<FrostedStore>().isLoggedIn) {
        unawaited(_restoreOrLoad(0));
      }
    });
  }

  @override
  void dispose() {
    _chrome?.removeListener(_onChromeChange);
    for (final s in _states) {
      s.dispose();
    }
    super.dispose();
  }

  void _onChromeChange() {
    if (!mounted) return;
    final count = context.read<ChromeController>().notificationsRefreshCount;
    if (count == _lastNotifyRefresh) return;
    _lastNotifyRefresh = count;
    final scroll = _states[_tab].scroll;
    if (scroll.hasClients && scroll.offset > 0) {
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    unawaited(_load(_tab, refresh: true));
  }

  void _onScroll(int tab) {
    final st = _states[tab];
    if (!st.scroll.hasClients) return;
    if (st.scroll.offset >= st.scroll.position.maxScrollExtent - 300 &&
        st.hasMore &&
        !st.loading &&
        !st.loadingMore) {
      unawaited(_load(tab, refresh: false));
    }
  }

  Future<void> _restoreOrLoad(int tab) async {
    final st = _states[tab];
    if (st.loadedOnce) return;
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      if (mounted) {
        setState(() {
          st.items = [];
          st.loading = false;
          st.loadedOnce = true;
        });
      }
      return;
    }
    final cached = await TabSnapshotCache.instance.readNotifications(
      _accountKey,
      tab: tab,
    );
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        st.items = cached.items;
        st.hasMore = cached.hasMore;
        st.loading = false;
        st.error = null;
        st.loadedOnce = true;
      });
      return;
    }
    await _load(tab, refresh: true);
  }

  Future<void> _load(int tab, {required bool refresh}) async {
    final st = _states[tab];
    final repo = context.read<TiebaRepo>();
    if (!repo.isLoggedIn) {
      setState(() {
        st.items = [];
        st.loading = false;
        st.loadedOnce = true;
      });
      return;
    }
    if (refresh) {
      setState(() {
        st.loading = st.items.isEmpty;
        st.error = null;
      });
    } else {
      setState(() => st.loadingMore = true);
    }
    try {
      final nextPage = refresh ? 1 : st.page + 1;
      final res = tab == 0
          ? await repo.getReplyMe(page: nextPage)
          : await repo.getAtMe(page: nextPage);
      if (!mounted) return;
      setState(() {
        st.items = refresh ? res.items : [...st.items, ...res.items];
        st.page = nextPage;
        st.hasMore = res.hasMore;
        st.loading = false;
        st.loadingMore = false;
        st.loadedOnce = true;
      });
      unawaited(
        TabSnapshotCache.instance.saveNotifications(
          _accountKey,
          tab: tab,
          items: st.items,
          hasMore: st.hasMore,
        ),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        st.error = cleanError(e);
        st.loading = false;
        st.loadingMore = false;
        st.loadedOnce = true;
      });
    }
  }

  void _switchTab(int next) {
    if (next == _tab) return;
    setState(() => _tab = next);
    context.read<ChromeController>().setHidden(false);
    if (!_states[next].loadedOnce && context.read<FrostedStore>().isLoggedIn) {
      unawaited(_restoreOrLoad(next));
    }
  }

  Widget _buildTab(
    BuildContext context,
    int tab,
    FrostedStore store,
    double top,
    double bottom,
  ) {
    if (!store.isLoggedIn) {
      return FrostedEmpty(
        title: '登录后查看消息通知',
        message: '查看回复我的帖子、楼中楼与 @提及',
        icon: FrostedGlyphs.bell,
        action: FilledButton(
          onPressed: () => openLogin(context),
          child: const Text('登录贴吧'),
        ),
      );
    }
    final st = _states[tab];
    if (!st.loadedOnce && !st.loading && st.items.isEmpty) {
      return const SizedBox.shrink();
    }
    if (st.loading && st.items.isEmpty) {
      return const FrostedLoading(label: '加载消息中...');
    }
    if (st.error != null && st.items.isEmpty) {
      return FrostedEmpty(
        title: '加载消息失败',
        message: st.error,
        icon: FrostedGlyphs.bell,
        action: FilledButton(
          onPressed: () => _load(tab, refresh: true),
          child: const Text('重试'),
        ),
      );
    }
    if (st.items.isEmpty) {
      return const FrostedEmpty(
        title: '暂无新消息',
        message: '有新回复或 @提醒时会显示在这里',
        icon: FrostedGlyphs.bell,
      );
    }
    return ListView.separated(
      controller: st.scroll,
      padding: EdgeInsets.fromLTRB(14, top + 8, 14, bottom),
      itemCount: st.items.length + (st.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        if (idx >= st.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: FrostedLoading(),
          );
        }
        final item = st.items[idx];
        return _NotificationCard(
          item: item,
          onTap: () => openThread(
            context,
            threadId: item.threadId,
            forumName: item.forumName,
            postId: item.postId > 0 ? item.postId : null,
            initialTitle: item.title,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = context.read<ChromeController>();
    final store = context.watch<FrostedStore>();
    final top = pageTopInset(context);
    final bottom = pageBottomInset(context);

    return PrismScaffold(
      bar: FrostedAppBar(
        bindChrome: true,
        title: SizedBox(
          width: 176,
          child: FrostedSegmentedControl<int>(
            value: _tab,
            onChanged: _switchTab,
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
          onRefresh: () => _load(_tab, refresh: true),
          child: IndexedStack(
            index: _tab,
            children: [
              _buildTab(context, 0, store, top, bottom),
              _buildTab(context, 1, store, top, bottom),
            ],
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
