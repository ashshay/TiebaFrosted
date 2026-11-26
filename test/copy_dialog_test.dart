import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/text_selection_menu.dart';
import 'package:tieba_frosted/ui/localizations.dart';
import 'package:tieba_frosted/ui/widgets/copy_dialog.dart';

/// 弹窗走 prism_ui 的对话框路由，需要 App 里那套 UiLocalizations 委托。
/// 页面里放一个按钮，由它用真正的页面上下文打开弹窗。
material.Widget _host(String text) => material.MaterialApp(
  localizationsDelegates: FrostedUiLocalizations.delegates,
  supportedLocales: const [Locale('en', 'US')],
  locale: const Locale('en', 'US'),
  home: material.Builder(
    builder: (context) => material.TextButton(
      onPressed: () => showCopyTextDialog(context, text),
      child: const material.Text('open'),
    ),
  ),
);

Future<void> _open(WidgetTester tester, String text) async {
  await tester.pumpWidget(_host(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('复制弹窗先展示全文，点「复制全部」才写进剪贴板', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _open(tester, '第一行\n第二行');

    // 弹窗里能看到全文与提示，点开时还没有动剪贴板。
    expect(find.textContaining('长按正文选中一段'), findsOneWidget);
    expect(find.text('第一行\n第二行'), findsOneWidget);
    expect(calls.where((c) => c.method == 'Clipboard.setData'), isEmpty);

    await tester.tap(find.text('复制全部'));
    await tester.pumpAndSettle();

    final writes = calls.where((c) => c.method == 'Clipboard.setData').toList();
    expect(writes, hasLength(1));
    expect((writes.single.arguments as Map)['text'], '第一行\n第二行');
    // 复制完弹窗自动关闭
    expect(find.text('复制全部'), findsNothing);
  });

  testWidgets('空内容不弹窗', (tester) async {
    await _open(tester, '   ');

    expect(find.text('复制全部'), findsNothing);
  });

  testWidgets('面板里长按正文可以框选（弹出选区菜单）', (tester) async {
    await _open(tester, '第一行 第二行 第三行');

    await tester.longPress(find.text('第一行 第二行 第三行'));
    await tester.pumpAndSettle();

    expect(find.byType(TextSelectionMenu), findsOneWidget);
  });
}
