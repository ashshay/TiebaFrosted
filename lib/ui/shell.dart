import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import '../data/native_channels.dart';
import '../data/settings.dart';
import '../data/store.dart';
import 'chrome.dart';
import 'pages/feed_page.dart';
import 'pages/home_page.dart';
import 'pages/me_page.dart';
import 'pages/notifications_page.dart';
import 'routes.dart';
import 'widgets/common.dart';
import 'widgets/glyphs.dart';
import 'widgets/remote_image.dart';

/// 应用主壳：四格页面（首页 / 动态 / 消息 / 我的）+ Prism 液态玻璃悬浮底栏。
///
/// 四格页面常驻 IndexedStack 保活（首次切换不触发重载），
/// 「首页」「动态」「消息」支持双击底栏图标回顶并手动刷新。
class FrostedShell extends StatefulWidget {
  const FrostedShell({super.key});

  @override
  State<FrostedShell> createState() => _FrostedShellState();
}

class _FrostedShellState extends State<FrostedShell> {
  int _index = 0;
  final GlobalKey _dockKey = GlobalKey();
  int? _lastTapIndex;
  DateTime? _lastTapAt;
  Timer? _longPressTimer;
  Offset? _pressStart;
  StreamSubscription<String>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _index = context.read<FrostedSettings>().startTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleInitialDeepLink());
    });
    // 冷启动走 initialLink，热启动走这条流；两者都交给同一个分发器。
    _deepLinkSub = NativeChannels.deepLinks().listen((link) {
      if (mounted) unawaited(openTiebaUrl(context, link));
    });
  }

  Future<void> _handleInitialDeepLink() async {
    final link = await NativeChannels.consumeInitialDeepLink();
    if (link != null && link.isNotEmpty && mounted) {
      unawaited(openTiebaUrl(context, link));
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onDockSelected(int index) {
    context.read<ChromeController>().setHidden(false);
    if (index == _index) return;
    setState(() => _index = index);
  }

  void _handleDockPointerDown(PointerDownEvent event) {
    _cancelLongPress();
    final box = _dockKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    _pressStart = event.position;
    if (_dockIndexAt(box.globalToLocal(event.position), box.size) != 3) return;
    if (!context.read<FrostedSettings>().quickSwitchAccount) return;
    if (!context.read<FrostedStore>().isLoggedIn) return;
    _longPressTimer = Timer(const Duration(milliseconds: 480), () {
      _longPressTimer = null;
      _pressStart = null;
      if (mounted) unawaited(_quickSwitchAccount());
    });
  }

  void _handleDockPointerMove(PointerMoveEvent event) {
    final start = _pressStart;
    if (start == null) return;
    if ((event.position - start).distance > 12) _cancelLongPress();
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _pressStart = null;
  }

  void _handleDockPointerUp(PointerUpEvent event) {
    _cancelLongPress();
    final box = _dockKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final index = _dockIndexAt(box.globalToLocal(event.position), box.size);
    if (index < 0) return;
    // 「首页」「动态」「消息」支持双击底栏手动刷新并回顶，「我的」保持单击切页。
    if (index > 2) {
      _lastTapIndex = null;
      return;
    }
    final now = DateTime.now();
    final lastAt = _lastTapAt;
    if (_lastTapIndex == index &&
        lastAt != null &&
        now.difference(lastAt) <= const Duration(milliseconds: 320)) {
      _lastTapIndex = null;
      _lastTapAt = null;
      HapticFeedback.lightImpact();
      final chrome = context.read<ChromeController>();
      chrome.setHidden(false);
      if (_index != index) {
        setState(() => _index = index);
      }
      switch (index) {
        case 0:
          chrome.requestHomeRefresh();
        case 1:
          chrome.requestFeedRefresh();
        case 2:
          chrome.requestNotificationsRefresh();
      }
    } else {
      _lastTapIndex = index;
      _lastTapAt = now;
    }
  }

  Future<void> _quickSwitchAccount() async {
    final store = context.read<FrostedStore>();
    final list = store.accounts;
    if (list.length < 2) {
      showFrostedToast(context, '只有一个账号，可在「设置 → 账号管理」添加更多账号');
      return;
    }
    HapticFeedback.mediumImpact();
    final activeUid = store.activeUid;
    final picked = await showFrostedChoices<String>(
      context,
      title: '快速切换账号',
      choices: [
        for (final acc in list)
          FrostedChoice(
            value: acc.uid,
            label: acc.displayName,
            subtitle: acc.uid == activeUid ? '当前账号' : 'UID ${acc.uid}',
            leading: Avatar(url: acc.portrait, size: 28),
            selected: acc.uid == activeUid,
          ),
      ],
    );
    if (picked == null || picked == activeUid || !mounted) return;
    await store.switchAccount(picked);
    if (mounted) {
      showFrostedToast(
        context,
        '已切换到 ${store.currentAccount?.displayName ?? ''}',
      );
    }
  }

  int _dockIndexAt(Offset local, Size size) {
    const count = 4;
    const edge = 21.0;
    const barPadding = 4.0;
    const maxBar = 360.0;
    const minLens = 84.0;
    final barWidth = math.min(size.width - edge * 2, maxBar);
    final barLeft = (size.width - barWidth) / 2;
    final span = barWidth - barPadding * 2;
    final pitch = (span - barPadding * 2) / count;
    final double itemWidth;
    final double inset;
    if (pitch + barPadding * 2 >= minLens) {
      itemWidth = pitch;
      inset = barPadding;
    } else {
      final lens = math.min(minLens, span);
      itemWidth = (span - lens) / (count - 1);
      inset = (lens - itemWidth) / 2;
    }
    final x = local.dx - barLeft - barPadding - inset;
    if (x < 0) return -1;
    return (x / itemWidth).floor().clamp(0, count - 1);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<FrostedStore>();
    final settings = context.watch<FrostedSettings>();
    final disabled = context.disableAnimations;

    final dockAvatar = settings.profileTabAvatar && store.isLoggedIn
        ? (store.currentAccount?.portrait ?? '')
        : '';

    final accountKey = store.activeUid ?? 'guest';
    final pages = <Widget>[
      HomePage(key: ValueKey('home-$accountKey')),
      FeedPage(key: ValueKey('feed-$accountKey')),
      NotificationsPage(key: ValueKey('msg-$accountKey')),
      MePage(key: ValueKey('me-$accountKey')),
    ];

    return Surface(
      color: SurfaceLevel.page.colorOf(context.colorScheme),
      child: Stack(
        children: [
          Positioned.fill(
            child: BottomInsetScope(
              inset: NavigationDock.insetOf(context),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Selector<ChromeController, bool>(
              selector: (_, chrome) => chrome.hidden,
              builder: (context, hidden, child) => IgnorePointer(
                ignoring: hidden,
                child: AnimatedSlide(
                  offset: hidden ? const Offset(0, 1) : Offset.zero,
                  duration: disabled
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: hidden ? 0 : 1,
                    duration: disabled
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: child,
                  ),
                ),
              ),
              child: Listener(
                onPointerDown: _handleDockPointerDown,
                onPointerMove: _handleDockPointerMove,
                onPointerUp: _handleDockPointerUp,
                onPointerCancel: (_) => _cancelLongPress(),
                child: NavigationDock(
                  key: _dockKey,
                  destinations: [
                    const NavigationDockDestination(
                      glyph: FrostedGlyphs.home,
                      label: '首页',
                    ),
                    const NavigationDockDestination(
                      glyph: FrostedGlyphs.explore,
                      label: '动态',
                    ),
                    const NavigationDockDestination(
                      glyph: FrostedGlyphs.bell,
                      label: '消息',
                    ),
                    NavigationDockDestination(
                      glyph: FrostedGlyphs.person,
                      label: '我的',
                      icon: dockAvatar.isEmpty
                          ? null
                          : Avatar(url: dockAvatar, size: 28),
                    ),
                  ],
                  selectedIndex: _index,
                  onSelected: _onDockSelected,
                  tintSelection: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
