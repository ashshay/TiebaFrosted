import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(CardPageRoute<T>(builder: (_) => page));
}

/// 轻量半透明看图路由：淡入 + 轻缩放，配合看图器下拉跟手关闭实时透出底层页面。
Future<T?> pushLightboxPage<T>(BuildContext context, Widget page) {
  final disableAnim = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierColor: null,
      transitionDuration: disableAnim
          ? Duration.zero
          : const Duration(milliseconds: 220),
      reverseTransitionDuration: disableAnim
          ? Duration.zero
          : const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => page,
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
