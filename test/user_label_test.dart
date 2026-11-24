import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/data/models.dart';

TiebaUser user({String name = '', String nameShow = ''}) =>
    TiebaUser(id: 1, name: name, nameShow: nameShow);

void main() {
  group('用户昵称 / 用户名展示', () {
    test('标题行只显示昵称', () {
      expect(user(name: 'qva224k_8821', nameShow: '贴吧用户_QVa224K').displayName,
          '贴吧用户_QVa224K');
    });

    test('用户名带 @ 前缀，供第二行使用', () {
      expect(user(name: 'qva224k_8821').atUserName, '@qva224k_8821');
    });

    test('没有用户名时 @ 形式是空串，不会出现孤零零的 @', () {
      expect(user(nameShow: '小明').atUserName, '');
      expect(user().atUserName, '');
    });

    test('没有昵称时标题行退回用户名', () {
      expect(user(name: 'abc').displayName, 'abc');
      expect(user().displayName, '贴吧用户');
    });
  });
}
