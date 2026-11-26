import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/core/html_text.dart';
import 'package:tieba_frosted/data/models.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/ui/localizations.dart';
import 'package:tieba_frosted/ui/widgets/post_tile.dart';

const _post = TiebaPost(
  id: 42,
  floor: 1,
  time: 1700000000,
  authorId: 7,
  author: TiebaUser(id: 7, name: 'alice', nameShow: '爱丽丝'),
  content: [RichTextNode('主楼正文，可以长按复制')],
);

Future<material.Widget> _host(Widget child) async {
  SharedPreferences.setMockInitialValues({});
  final settings = FrostedSettings(await SharedPreferences.getInstance());
  return ChangeNotifierProvider<FrostedSettings>.value(
    value: settings,
    child: material.MaterialApp(
      localizationsDelegates: FrostedUiLocalizations.delegates,
      supportedLocales: const [Locale('en', 'US')],
      locale: const Locale('en', 'US'),
      home: material.Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('长按正文走「复制」入口，长按卡片其它位置仍开楼层菜单', (tester) async {
    var copy = 0;
    var more = 0;
    await tester.pumpWidget(
      await _host(
        PostTile(
          post: _post,
          isFirstFloor: true,
          onCopyTap: () => copy++,
          onMoreTap: () => more++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 正文：长按直接去复制面板
    await tester.longPress(find.text('主楼正文，可以长按复制'));
    await tester.pumpAndSettle();
    expect(copy, 1);
    expect(more, 0);

    // 作者名那一行：长按仍是楼层菜单
    await tester.longPress(find.text('爱丽丝'));
    await tester.pumpAndSettle();
    expect(more, 1);
  });

  testWidgets('没有 onCopyTap 时正文长按仍落到楼层菜单', (tester) async {
    var more = 0;
    await tester.pumpWidget(
      await _host(PostTile(post: _post, onMoreTap: () => more++)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('主楼正文，可以长按复制'));
    await tester.pumpAndSettle();
    expect(more, 1);
  });

  testWidgets('主楼标题旁也画出「…」入口', (tester) async {
    await tester.pumpWidget(
      await _host(PostTile(post: _post, onMoreTap: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('更多操作'), findsOneWidget);
  });
}
