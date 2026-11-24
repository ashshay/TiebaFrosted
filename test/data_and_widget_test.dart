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
import 'package:tieba_frosted/data/updater.dart';
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

    test('keeps only general partitions out of nav_tab_info', () {
      final resp = ProtoWriter()
        ..writeSubMessage(2, (data) {
          data.writeSubMessage(2, (forum) {
            forum.writeInt64(1, 88);
            forum.writeString(2, 'flutter');
          });
          data.writeSubMessage(37, (nav) {
            nav.writeSubMessage(1, (tab) {
              tab.writeInt32(1, 101);
              tab.writeInt32(2, 15);
              tab.writeString(3, '吧友互助');
              tab.writeInt32(7, 1); // is_general_tab
              tab.writeSubMessage(19, (sort) {
                sort.writeString(1, '按回复时间');
                sort.writeInt32(2, 0);
              });
              tab.writeSubMessage(19, (sort) {
                sort.writeString(1, '按发帖时间');
                sort.writeInt32(2, 1);
              });
            });
            nav.writeSubMessage(1, (tab) {
              tab.writeInt32(1, 102);
              tab.writeInt32(2, 15);
              tab.writeString(3, '活动');
              tab.writeInt32(7, 0); // 不是通用分区
            });
            nav.writeSubMessage(1, (tab) {
              tab.writeInt32(1, 103);
              tab.writeInt32(2, 1); // tabType 不是 15
              tab.writeString(3, '图册');
              tab.writeInt32(7, 1);
            });
          });
        });

      final parsed = TiebaProtoCodec.decodeFrsPageResponse(resp.toBytes());
      expect(parsed.navTabs.length, 3);
      expect(parsed.generalTabs.map((tab) => tab.tabName), ['吧友互助']);
      final partition = parsed.generalTabs.single;
      expect(partition.tabId, 101);
      expect(partition.isDefault, isFalse);
      expect(partition.sortMenu.map((sort) => sort.sortName), [
        '按回复时间',
        '按发帖时间',
      ]);
      expect(partition.sortMenu.last.sortType, 1);
    });

    test('decodes a general tab page with author hydration and cursor', () {
      final resp = ProtoWriter()
        ..writeSubMessage(2, (data) {
          data.writeSubMessage(1, (thread) {
            thread.writeInt64(1, 9001);
            thread.writeInt64(2, 40001);
            thread.writeString(3, '分区里的帖子');
            thread.writeInt64(56, 777);
          });
          data.writeInt32(2, 1); // has_more
          data.writeSubMessage(3, (user) {
            user.writeInt64(2, 777);
            user.writeString(4, '分区楼主');
          });
          data.writeInt32(7, 1); // sort_type
        });

      final parsed = TiebaProtoCodec.decodeGeneralTabListResponse(
        resp.toBytes(),
      );
      expect(parsed.threads, hasLength(1));
      expect(parsed.threads.single.displayTitle, '分区里的帖子');
      expect(parsed.threads.single.author.displayName, '分区楼主');
      expect(parsed.hasMore, isTrue);
      expect(parsed.sortType, 1);
      // 游标取 ThreadInfo.id，与 TiebaLite 的 last_thread_id 同源。
      expect(parsed.lastThreadId, 9001);
    });

    test('general tab request carries the partition identity', () {
      const tab = ForumTab(
        tabId: 101,
        tabType: 15,
        tabName: '吧友互助',
        isGeneralTab: true,
        isDefault: true,
      );
      final bytes = TiebaProtoCodec.encodeGeneralTabListRequest(
        device: TiebaDevice.ephemeral(),
        forumId: 88,
        tab: tab,
        sortType: 1,
        page: 2,
        lastThreadId: 40001,
      );
      // 外层 GeneralTabListRequest { data = 1 }，内层按 proto 字段号抽查。
      final outer = ProtoReader(bytes);
      final field = outer.nextField();
      expect(field?.tag, 1);
      final data = outer.readSubReader();
      final values = <int, int>{};
      var tabName = '';
      data.forEachField((tag, wire, reader) {
        if (tag == 2) {
          values[2] = reader.readInt32();
          return true;
        }
        if (tag == 3) {
          values[3] = reader.readVarint();
          return true;
        }
        if (tag == 4) {
          values[4] = reader.readInt32();
          return true;
        }
        if (tag == 9) {
          values[9] = reader.readVarint();
          return true;
        }
        if (tag == 11) {
          tabName = reader.readString();
          return true;
        }
        if (tag == 13) {
          values[13] = reader.readInt32();
          return true;
        }
        if (tag == 14) {
          values[14] = reader.readInt32();
          return true;
        }
        return false;
      });
      expect(values[2], 101);
      expect(values[3], 88);
      expect(values[4], 2);
      expect(values[9], 40001);
      expect(tabName, '吧友互助');
      expect(values[13], 1);
      expect(values[14], 15);
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
          updater: FrostedUpdater(prefs),
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
