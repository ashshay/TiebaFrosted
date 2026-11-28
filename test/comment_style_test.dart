import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/core/html_text.dart';
import 'package:tieba_frosted/data/models.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/ui/theme.dart';
import 'package:tieba_frosted/ui/widgets/common.dart';
import 'package:tieba_frosted/ui/widgets/post_tile.dart';

const _post = TiebaPost(
  id: 42,
  floor: 4,
  time: 1764000000,
  authorId: 7,
  author: TiebaUser(
    id: 7,
    name: 'alice',
    nameShow: '爱丽丝',
    ipAddress: '陕西',
    levelId: 12,
  ),
  content: [RichTextNode('评论区正文')],
  subPostNumber: 4,
  agree: TiebaAgree(agreeNum: 2),
);

const _firstFloorPost = TiebaPost(
  id: 41,
  floor: 1,
  time: 1764000000,
  authorId: 7,
  author: TiebaUser(
    id: 7,
    name: 'alice',
    nameShow: '爱丽丝',
    ipAddress: '陕西',
    levelId: 12,
  ),
  content: [RichTextNode('主楼正文')],
  agree: TiebaAgree(agreeNum: 2),
);

Future<FrostedSettings> _host(
  WidgetTester tester,
  Widget tile, {
  CommentStyle style = CommentStyle.card,
}) async {
  SharedPreferences.setMockInitialValues({'comment_style': style.index});
  final settings = FrostedSettings(await SharedPreferences.getInstance());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(393, 900)),
        child: ChangeNotifierProvider<FrostedSettings>.value(
          value: settings,
          child: Theme(
            data: frostedTheme(
              brightness: Brightness.light,
              accentArgb: defaultAccent.toARGB32(),
            ),
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: tile,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return settings;
}

void main() {
  testWidgets('融合样式：铺在页面上、发帖地可见、楼中楼收进圆角条', (tester) async {
    var subPosts = 0;
    await _host(
      tester,
      PostTile(
        post: _post,
        onSubPostsTap: () => subPosts++,
        onMoreTap: () {},
      ),
      style: CommentStyle.merged,
    );

    expect(find.byType(FrostedCard), findsNothing);
    expect(find.textContaining('陕西'), findsOneWidget);
    expect(
      find.text('查看全部 ${_post.subPostNumber} 条回复'),
      findsOneWidget,
    );
    // 融合样式不再渲染楼层的等级徽标。
    expect(find.text('Lv.12'), findsNothing);

    await tester.tap(find.text('查看全部 4 条回复'));
    await tester.pump();
    expect(subPosts, 1);
  });

  testWidgets('融合样式下首楼仍是一张卡片', (tester) async {
    await _host(
      tester,
      PostTile(
        post: _firstFloorPost,
        isFirstFloor: true,
        onMoreTap: () {},
        onReplyTap: () {},
      ),
      style: CommentStyle.merged,
    );

    expect(find.byType(FrostedCard), findsOneWidget);
    expect(find.text('主楼正文'), findsOneWidget);
    expect(find.text('Lv.12'), findsOneWidget);
    expect(find.textContaining('陕西'), findsOneWidget);
  });

  testWidgets('楼中楼页顶部那块普通楼层跟随融合排版', (tester) async {
    await _host(
      tester,
      PostTile(
        post: _post,
        isFirstFloor: true,
        onMoreTap: () {},
        onReplyTap: () {},
      ),
      style: CommentStyle.merged,
    );

    expect(find.byType(FrostedCard), findsNothing);
    expect(find.text('评论区正文'), findsOneWidget);
  });

  testWidgets('卡片样式保持原样：卡片、发帖地、等级徽标与回复入口都在', (tester) async {
    await _host(tester, PostTile(post: _post, onMoreTap: () {}));

    expect(find.byType(FrostedCard), findsOneWidget);
    expect(find.textContaining('陕西'), findsOneWidget);
    expect(find.text('Lv.12'), findsOneWidget);
    expect(find.text('查看全部 4 条回复'), findsOneWidget);
  });

  test('评论区样式写入 SharedPreferences 后可读回', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = FrostedSettings(prefs);
    expect(settings.commentStyle, CommentStyle.card);

    await settings.setCommentStyle(CommentStyle.merged);
    expect(prefs.getInt('comment_style'), CommentStyle.merged.index);
    expect(
      FrostedSettings(prefs).commentStyle,
      CommentStyle.merged,
    );
  });

  test('楼中楼分页：has_more 为 0 时仍按 total_page 继续翻页', () {
    const page = TiebaPageInfo(totalPage: 99, currentPage: 1);
    expect(page.hasMore, isFalse);
    expect(page.hasMoreAfter(1), isTrue);
    expect(page.hasMoreAfter(98), isTrue);
    expect(page.hasMoreAfter(99), isFalse);

    const singlePage = TiebaPageInfo(totalPage: 1, currentPage: 1);
    expect(singlePage.hasMoreAfter(1), isFalse);

    const serverSaysMore = TiebaPageInfo(totalPage: 1, hasMore: true);
    expect(serverSaysMore.hasMoreAfter(1), isTrue);
  });
}
