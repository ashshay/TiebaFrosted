import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import 'predictive_back.dart';

Future<T?> pushPage<T>(
  BuildContext context,
  Widget page, {
  bool dragBack = true,
}) {
  return Navigator.of(context).push<T>(
    _FrostedCardPageRoute<T>(
      builder: (_) => PredictiveBackHost(child: page),
      dragBackEnabled: dragBack,
    ),
  );
}

/// 轻量半透明看图路由：淡入 + 轻缩放，配合看图器下拉跟手关闭实时透出底层页面。
Future<T?> pushLightboxPage<T>(BuildContext context, Widget page) {
  final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context).push<T>(
    _FrostedLightboxRoute<T>(
      opaque: false,
      barrierColor: null,
      transitionDuration: disableAnim
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseTransitionDuration: disableAnim
          ? Duration.zero
          : const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => PredictiveBackHost(child: page),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    ),
  );
}

Future<T?> openDialog<T>(BuildContext context, Widget child) =>
    showFloatingDialog<T>(context: context, child: child);

/// 覆写预测性返回的提交 / 取消收尾：
///
/// Flutter 默认的 [TransitionRoute.handleCommitBackGesture] 会在 `navigator.pop()`
/// 后强行调用 `controller.reverse(from: 1.0)`，既把已滑出的卡片跳回起点，又把
/// [CardRouteMixin.didPop] 的 300ms 弹簧替换成 ~550ms 线性匀速退场；
/// 取消手势时的 `controller.forward()` 同样走线性长时长。这里直接沿用
/// [CardRouteMixin.settleTo] 的弹簧从当前进度收尾。
class _FrostedCardPageRoute<T> extends CardPageRoute<T> {
  _FrostedCardPageRoute({required super.builder, super.dragBackEnabled});

  @override
  void handleCommitBackGesture() {
    if (isCurrent) {
      navigator?.pop();
    }
    navigator?.didStopUserGesture();
  }

  @override
  void handleCancelBackGesture() {
    final ctrl = controller;
    if (isCurrent && ctrl != null && !ctrl.isCompleted) {
      settleTo(1);
    }
    navigator?.didStopUserGesture();
  }
}

/// 看图器路由的预测性返回提交：直接从当前进度 pop 淡出，避免默认实现
/// `reverse(from: 1.0)` 造成画面先闪回不透明再退出。
class _FrostedLightboxRoute<T> extends PageRouteBuilder<T> {
  _FrostedLightboxRoute({
    required super.pageBuilder,
    required super.transitionsBuilder,
    super.transitionDuration,
    super.reverseTransitionDuration,
    super.opaque,
    super.barrierColor,
  });

  @override
  void handleCommitBackGesture() {
    if (isCurrent) {
      navigator?.pop();
    }
    navigator?.didStopUserGesture();
  }
}
