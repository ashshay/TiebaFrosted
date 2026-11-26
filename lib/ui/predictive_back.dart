import 'package:flutter/services.dart' show PredictiveBackEvent;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/settings.dart';

/// 把 Android 14+ 的预测性返回手势接到当前路由的动画上。
///
/// Flutter 的 [TransitionRoute] 本身已经实现了「手势进度 → 路由动画」
/// （`handleStartBackGesture` / `handleUpdateBackGestureProgress` …），但只有
/// [PageTransitionsBuilder] 会去监听系统事件。本项目的转场来自 prism_ui 的
/// `CardPageRoute`，不走主题里的 builder，所以这里补一个监听者：把手势进度
/// 直接喂给当前路由，被滑走的卡片就会跟手，松手时按普通 pop / 回弹收尾。
///
/// 只在最上层、且允许手势返回的路由（`dragBack: false` 的页面会返回 false）
/// 上接管；系统返回键这类非手势事件交回框架走普通 pop。
class PredictiveBackHost extends StatefulWidget {
  const PredictiveBackHost({super.key, required this.child, this.enabled});

  final Widget child;

  /// 为空时跟随设置里的「预测性返回手势」开关（每次手势都重新读，改完立刻生效）。
  final bool? enabled;

  @override
  State<PredictiveBackHost> createState() => _PredictiveBackHostState();
}

class _PredictiveBackHostState extends State<PredictiveBackHost>
    with WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;

  bool get _enabled =>
      widget.enabled ??
      (context.read<FrostedSettings?>()?.predictiveBack ?? true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 回调发生在 build 之外，先把路由缓存下来，免得在那里取 InheritedWidget。
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    final route = _route;
    if (route == null ||
        backEvent.isButtonEvent ||
        !_enabled ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    // 手势进度是「已返回多少」，路由动画是「页面还在多少」，两者互补。
    route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    _route?.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCommitBackGesture() => _route?.handleCommitBackGesture();

  @override
  void handleCancelBackGesture() => _route?.handleCancelBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}
