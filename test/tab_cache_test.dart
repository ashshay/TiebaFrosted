import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/app.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/cookie_vault.dart';
import 'package:tieba_frosted/data/local_db.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/models.dart';
import 'package:tieba_frosted/data/repo.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/data/store.dart';
import 'package:tieba_frosted/data/updater.dart';
import 'package:tieba_frosted/data/tab_cache.dart';
import 'package:tieba_frosted/ui/pages/feed_page.dart';
import 'package:tieba_frosted/ui/pages/home_page.dart';

void main() {
  group('TabSnapshotCache disk persistence', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tieba_tab_cache_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('round-trips all 4 main tabs snapshots to disk', () async {
      final cache1 = TabSnapshotCache(cacheDirProvider: () async => tempDir);
      await cache1.saveFollowedForums('1001', const [
        FollowedForum(forumId: 1, forumName: 'flutter', levelId: 12, isSign: true),
      ]);
      await cache1.saveFeedRec('1001', const [
        TiebaThread(id: 99, threadId: 99, title: '缓存帖子', forumName: 'flutter'),
      ]);
      await cache1.saveFeedConcern(
        '1001',
        const ConcernPageResult(
          threads: [TiebaThread(id: 100, threadId: 100, title: '关注缓存')],
          pageTag: 'tag1',
          hasMore: true,
          requestUnix: 12345,
        ),
      );
      await cache1.saveFeedHot(
        '1001',
        data: const HotThreadPageResult(
          topics: [HotTopicItem(topicId: 7, topicName: '热议话题', discussNum: 88)],
          threads: [TiebaThread(id: 101, threadId: 101, title: '热榜帖子')],
          tabs: [ForumTab(tabId: 1, tabType: 0, tabName: '全部', tabCode: 'all')],
        ),
        tabCode: 'all',
        tabId: '1',
      );
      await cache1.saveNotifications(
        '1001',
        tab: 0,
        items: const [
          NotificationItem(
            threadId: 200,
            postId: 201,
            title: '回复标题',
            content: '回复正文',
            userName: '吧友A',
          ),
        ],
        hasMore: true,
      );
      await cache1.saveMeProfile(
        '1001',
        const TiebaUser(id: 1001, name: 'alice', nameShow: '爱丽丝', fansNum: 42),
      );

      final cache2 = TabSnapshotCache(cacheDirProvider: () async => tempDir);
      final forums = await cache2.readFollowedForums('1001');
      expect(forums?.single.forumName, 'flutter');
      final rec = await cache2.readFeedRec('1001');
      expect(rec?.single.title, '缓存帖子');
      final concern = await cache2.readFeedConcern('1001');
      expect(concern?.pageTag, 'tag1');
      expect(concern?.threads.single.title, '关注缓存');
      final hot = await cache2.readFeedHot('1001');
      expect(hot?.data.topics.single.topicName, '热议话题');
      expect(hot?.data.threads.single.title, '热榜帖子');
      final notif = await cache2.readNotifications('1001', tab: 0);
      expect(notif?.items.single.content, '回复正文');
      final me = await cache2.readMeProfile('1001');
      expect(me?.fansNum, 42);
    });
  });

  group('Main shell tab cache & double-tap refresh', () {
    tearDown(() {
      TabSnapshotCache.instance.configureForTesting(null);
    });

    testWidgets(
      'first switch across 4 tabs uses cache with 0 reloads; double-tap refreshes 首页/动态/消息',
      (tester) async {
        TabSnapshotCache.instance.configureForTesting(() async => null);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settings = FrostedSettings(prefs);
        final db = LocalDb.inMemory();
        await db.upsertAccount(
          const AccountRecord(
            uid: '1001',
            name: 'alice',
            nameShow: '爱丽丝',
            bduss: 'BDUSS_TEST',
            stoken: 'ST_TEST',
          ),
        );
        final cookies = CookieVault();
        final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
        await store.init();

        // 预置 4 个一级页面快照
        await TabSnapshotCache.instance.saveFollowedForums('1001', const [
          FollowedForum(forumId: 1, forumName: '缓存测试', levelId: 8),
        ]);
        await TabSnapshotCache.instance.saveFeedRec('1001', const [
          TiebaThread(id: 501, threadId: 501, title: '本地快照推荐帖'),
        ]);
        await TabSnapshotCache.instance.saveNotifications(
          '1001',
          tab: 0,
          items: const [
            NotificationItem(
              threadId: 601,
              postId: 602,
              title: '原帖',
              content: '本地快照消息内容',
              userName: '发信人',
            ),
          ],
          hasMore: false,
        );
        await TabSnapshotCache.instance.saveMeProfile(
          '1001',
          const TiebaUser(id: 1001, name: 'alice', nameShow: '爱丽丝', fansNum: 99),
        );

        final requestedPaths = <String>[];
        final dio = Dio()
          ..httpClientAdapter = _CountingAdapter((opts) {
            requestedPaths.add(opts.path);
          });
        final api = TiebaApi(
          device: TiebaDevice.ephemeral(),
          dio: dio,
          credentialProvider: () => (
            bduss: store.bduss,
            stoken: store.stoken,
            tbs: store.tbs,
            uid: store.uid,
            zid: store.zid,
            webCookie: store.webCookie,
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

        // 记录切页前的 State 实例，锁死切页过程中绝不发生子树卸载重建
        final homeStateBefore = tester.state(
          find.byType(HomePage, skipOffstage: false),
        );
        final feedStateBefore = tester.state(
          find.byType(FeedPage, skipOffstage: false),
        );

        // 依次首次切换到 动态 -> 消息 -> 我的：全部命中本地快照，0 次网络重载
        expect(find.text('缓存测试吧'), findsOneWidget);
        await tester.tap(find.text('动态'));
        await tester.pumpAndSettle();
        expect(find.text('本地快照推荐帖'), findsOneWidget);

        await tester.tap(find.text('消息'));
        await tester.pumpAndSettle();
        expect(find.text('本地快照消息内容'), findsOneWidget);

        await tester.tap(find.text('我的'));
        await tester.pumpAndSettle();
        expect(find.text('99'), findsOneWidget);

        expect(
          identical(
            tester.state(find.byType(HomePage, skipOffstage: false)),
            homeStateBefore,
          ),
          isTrue,
          reason: '切换底栏不得重建 HomePage State',
        );
        expect(
          identical(
            tester.state(find.byType(FeedPage, skipOffstage: false)),
            feedStateBefore,
          ),
          isTrue,
          reason: '切换底栏不得重建 FeedPage State',
        );
        expect(requestedPaths, isEmpty);

        // 双击底栏「消息」-> 触发手动刷新
        await tester.tap(find.text('消息'));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.text('消息'));
        await tester.pumpAndSettle();
        expect(
          requestedPaths.any((p) => p.contains('replyme')),
          isTrue,
          reason: '双击消息应触发回复我刷新',
        );

        // 双击底栏「动态」-> 触发手动刷新
        requestedPaths.clear();
        await tester.tap(find.text('动态'));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.text('动态'));
        await tester.pumpAndSettle();
        expect(
          requestedPaths.any((p) => p.contains('personalized')),
          isTrue,
          reason: '双击动态应触发推荐流刷新',
        );

        // 双击底栏「首页」-> 触发手动刷新
        requestedPaths.clear();
        await tester.tap(find.text('首页'));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(find.text('首页'));
        await tester.pumpAndSettle();
        expect(
          requestedPaths.any((p) => p.contains('forumGuide')),
          isTrue,
          reason: '双击首页应触发关注贴吧刷新',
        );
      },
    );
  });
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.onRequest);

  final void Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    if (options.responseType == ResponseType.bytes) {
      return ResponseBody.fromBytes(const [0x12, 0x00], 200);
    }
    return ResponseBody.fromString('{"error_code":"0"}', 200);
  }

  @override
  void close({bool force = false}) {}
}
