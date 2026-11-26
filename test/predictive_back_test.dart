import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/ui/predictive_back.dart';

/// 从平台侧发一条预测性返回事件（与 Android 侧 `flutter/backgesture` 同格式）。
Future<void> _send(
  WidgetTester tester,
  String method, {
  double progress = 0,
}) {
  final isGesture =
      method == 'startBackGesture' || method == 'updateBackGestureProgress';
  final args = isGesture
      ? <String, Object?>{
          'touchOffset': <double>[10, 300],
          'progress': progress,
          'swipeEdge': 0,
        }
      : null;
  unawaited(
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      null,
    ),
  );
  return tester.pump();
}

CardPageRoute<void> _cardRoute(Widget child, {bool dragBack = true}) =>
    CardPageRoute<void>(
      builder: (_) => PredictiveBackHost(child: child),
      dragBackEnabled: dragBack,
    );

Future<GlobalKey<NavigatorState>> _pumpApp(WidgetTester tester) async {
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    material.MaterialApp(navigatorKey: navKey, home: const Text('root')),
  );
  return navKey;
}

void main() {
  testWidgets('拖动系统返回手势时卡片跟手，松手取消则回弹', (tester) async {
    final navKey = await _pumpApp(tester);
    final route = _cardRoute(const Text('page2'));
    unawaited(navKey.currentState!.push(route));
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);

    await _send(tester, 'startBackGesture', progress: 0.3);
    expect(route.animation!.value, closeTo(0.7, 0.01));

    await _send(tester, 'updateBackGestureProgress', progress: 0.6);
    expect(route.animation!.value, closeTo(0.4, 0.01));

    await _send(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    expect(find.text('page2'), findsOneWidget);
  });

  testWidgets('松手提交后按普通返回处理', (tester) async {
    final navKey = await _pumpApp(tester);
    unawaited(navKey.currentState!.push(_cardRoute(const Text('page2'))));
    await tester.pumpAndSettle();

    await _send(tester, 'startBackGesture', progress: 0.8);
    await _send(tester, 'commitBackGesture');
    await tester.pumpAndSettle();

    expect(find.text('page2'), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('只有最顶层页面跟手，下面的页面不动', (tester) async {
    final navKey = await _pumpApp(tester);
    final below = _cardRoute(const Text('page2'));
    unawaited(navKey.currentState!.push(below));
    await tester.pumpAndSettle();
    final top = _cardRoute(const Text('page3'));
    unawaited(navKey.currentState!.push(top));
    await tester.pumpAndSettle();

    await _send(tester, 'startBackGesture', progress: 0.4);
    expect(top.animation!.value, closeTo(0.6, 0.01));
    expect(below.animation!.value, 1);

    await _send(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(top.animation!.value, 1);
  });

  testWidgets('拖拽返回被禁用的页面不接管，但仍能按系统返回退出', (tester) async {
    final navKey = await _pumpApp(tester);
    final route = _cardRoute(const Text('locked'), dragBack: false);
    unawaited(navKey.currentState!.push(route));
    await tester.pumpAndSettle();

    await _send(tester, 'startBackGesture', progress: 0.5);
    expect(route.animation!.value, 1);

    await _send(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsNothing);
  });

  testWidgets('开关关掉后不跟手，松手仍按普通返回处理', (tester) async {
    final navKey = await _pumpApp(tester);
    final route = CardPageRoute<void>(
      builder: (_) =>
          const PredictiveBackHost(enabled: false, child: Text('page2')),
    );
    unawaited(navKey.currentState!.push(route));
    await tester.pumpAndSettle();

    await _send(tester, 'startBackGesture', progress: 0.4);
    expect(route.animation!.value, 1);

    await _send(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('page2'), findsNothing);
  });

  testWidgets('未显式指定时跟随设置里的开关', (tester) async {
    SharedPreferences.setMockInitialValues({'predictive_back': false});
    final settings = FrostedSettings(await SharedPreferences.getInstance());
    expect(settings.predictiveBack, isFalse);

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<FrostedSettings>.value(
        value: settings,
        child: material.MaterialApp(
          navigatorKey: navKey,
          home: const Text('root'),
        ),
      ),
    );
    final route = _cardRoute(const Text('page2'));
    unawaited(navKey.currentState!.push(route));
    await tester.pumpAndSettle();

    await _send(tester, 'startBackGesture', progress: 0.4);
    expect(route.animation!.value, 1);

    // 打开开关后立刻生效，不用重开页面。
    await settings.setPredictiveBack(true);
    await tester.pump();
    await _send(tester, 'startBackGesture', progress: 0.4);
    expect(route.animation!.value, closeTo(0.6, 0.01));

    await _send(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
  });
}
