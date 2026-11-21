import 'dart:typed_data';
import 'dart:ui' show Brightness;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/app.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/core/proto_wire.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/cookie_vault.dart';
import 'package:tieba_frosted/data/local_db.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/models.dart';
import 'package:tieba_frosted/data/proto_codec.dart';
import 'package:tieba_frosted/data/repo.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/data/store.dart';
import 'package:tieba_frosted/ui/theme.dart';

void main() {
  group('Theme & SurfaceLevel hierarchy', () {
    test('all 4 ColorStyle modes build cleanly in light & dark', () {
      for (final style in ColorStyle.values) {
        for (final brightness in Brightness.values) {
          final theme = frostedTheme(
            brightness: brightness,
            accentArgb: defaultAccent.toARGB32(),
            style: style,
          );
          expect(theme.colorScheme.brightness, brightness);
        }
      }
    });

    test('dark mode surface levels monotonically ascend (never drop)', () {
      for (final style in ColorStyle.values) {
        final scheme = frostedTheme(
          brightness: Brightness.dark,
          accentArgb: defaultAccent.toARGB32(),
          style: style,
        ).colorScheme;
        final lPage = SurfaceLevel.page.colorOf(scheme).computeLuminance();
        final lCard = SurfaceLevel.card.colorOf(scheme).computeLuminance();
        final lBlock = SurfaceLevel.block.colorOf(scheme).computeLuminance();
        final lInset = SurfaceLevel.inset.colorOf(scheme).computeLuminance();
        expect(lCard, greaterThanOrEqualTo(lPage));
        expect(lBlock, greaterThanOrEqualTo(lCard));
        expect(lInset, greaterThanOrEqualTo(lBlock));
      }
    });
  });

  group('FrostedStore & LocalDb (in-memory)', () {
    test('multi-account switching, block rules, and whitelist precedence', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = LocalDb.inMemory();
      final cookies = CookieVault();
      final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
      await store.init();

      expect(store.isLoggedIn, isFalse);

      await store.saveAccount(
        const AccountRecord(
          uid: '1001',
          name: 'alice',
          nameShow: '爱丽丝',
          bduss: 'BDUSS_A',
          stoken: 'ST_A',
        ),
      );
      await store.saveAccount(
        const AccountRecord(
          uid: '1002',
          name: 'bob',
          nameShow: '鲍勃',
          bduss: 'BDUSS_B',
          stoken: 'ST_B',
        ),
      );
      expect(store.accounts.length, 2);
      expect(store.activeUid, '1002');
      expect(store.bduss, 'BDUSS_B');

      await store.switchAccount('1001');
      expect(store.activeUid, '1001');
      expect(store.bduss, 'BDUSS_A');

      await store.addBlockRule(type: BlockRuleType.keyword, value: '广告');
      await store.addBlockRule(
        type: BlockRuleType.keyword,
        value: r'促销\d+元',
        isRegex: true,
      );
      await store.addBlockRule(
        type: BlockRuleType.forum,
        value: '水贴',
      );
      await store.addBlockRule(
        type: BlockRuleType.user,
        value: '官方',
        isWhitelist: true,
      );

      expect(store.shouldBlock(text: '这是广告贴'), isTrue);
      expect(store.shouldBlock(text: '全场促销99元'), isTrue);
      expect(store.shouldBlock(forumName: '水贴', text: '普通标题'), isTrue);
      // 白名单用户豁免
      expect(store.shouldBlock(text: '这是广告贴', userName: '官方'), isFalse);
      expect(store.shouldBlock(text: '正常讨论'), isFalse);
    });
  });

  group('TiebaProtoCodec error & response decoding', () {
    test('throws TiebaApiException when Error.error_code != 0', () {
      final outer = ProtoWriter()
        ..writeSubMessage(1, (err) {
          err.writeInt32(1, 220034);
          err.writeString(2, '您操作太频繁');
        });
      expect(
        () => TiebaProtoCodec.unwrapResponse(outer.toBytes()),
        throwsA(
          isA<TiebaApiException>()
              .having((e) => e.code, 'code', 220034)
              .having((e) => e.message, 'message', '您操作太频繁'),
        ),
      );
    });

    test('hydrates post author from PbPageResponseData.user_list', () {
      final resp = ProtoWriter()
        ..writeSubMessage(2, (data) {
          data.writeSubMessage(2, (forum) {
            forum.writeInt64(1, 88);
            forum.writeString(2, 'flutter');
          });
          data.writeSubMessage(6, (post) {
            post.writeInt64(1, 5001);
            post.writeUint32(3, 1);
            post.writeInt64(19, 777); // author_id
            post.writeSubMessage(5, (c) {
              c.writeInt32(1, 0);
              c.writeString(2, '正文内容');
            });
          });
          data.writeSubMessage(13, (user) {
            user.writeInt64(2, 777);
            user.writeString(4, '测试楼主');
            user.writeInt32(23, 10);
          });
        });

      final parsed = TiebaProtoCodec.decodePbPageResponse(resp.toBytes());
      expect(parsed.forum.name, 'flutter');
      expect(parsed.posts.length, 1);
      expect(parsed.posts.first.author.displayName, '测试楼主');
      expect(parsed.posts.first.author.levelId, 10);
      expect(parsed.firstFloorPost?.id, 5001);
    });
  });

  group('TiebaFrostedApp widget smoke test', () {
    testWidgets('boots PrismApp with 4-tab NavigationDock cleanly', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = FrostedSettings(prefs);
      final db = LocalDb.inMemory();
      final cookies = CookieVault();
      final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
      await store.init();
      final dio = Dio()..httpClientAdapter = _EmptyProtoAdapter();
      final api = TiebaApi(
        device: TiebaDevice.ephemeral(),
        dio: dio,
        credentialProvider: () => (
          bduss: '',
          stoken: '',
          tbs: '',
          uid: '',
          zid: '',
          webCookie: '',
        ),
      );
      final repo = TiebaRepo(
        api: api,
        store: store,
        settings: settings,
        db: db,
        mediaSaver: MediaSaver(api.rawDio),
      );

      await tester.pumpWidget(
        TiebaFrostedApp(
          settings: settings,
          store: store,
          db: db,
          mediaSaver: MediaSaver(api.rawDio),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('动态'), findsOneWidget);
      expect(find.text('消息'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
    });
  });
}

class _EmptyProtoAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(const [0x12, 0x00], 200);
  }

  @override
  void close({bool force = false}) {}
}
