import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/cookie_vault.dart';
import 'package:tieba_frosted/data/local_db.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/repo.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/data/store.dart';
import 'package:tieba_frosted/data/tab_cache.dart';
import 'package:tieba_frosted/ui/chrome.dart';
import 'package:tieba_frosted/ui/localizations.dart';
import 'package:tieba_frosted/ui/pages/me_page.dart';
import 'package:tieba_frosted/ui/theme.dart';

class _EmptyAdapter implements HttpClientAdapter {
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

Future<Widget> _buildHost({
  required bool loggedIn,
  required Size size,
  EdgeInsets padding = const EdgeInsets.only(top: 44, bottom: 24),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = FrostedSettings(prefs);
  final db = LocalDb.inMemory();
  if (loggedIn) {
    await db.upsertAccount(
      const AccountRecord(
        uid: '1001',
        name: 'alice',
        nameShow: '直格-',
        bduss: 'BDUSS_TEST',
        stoken: 'ST_TEST',
      ),
    );
  }
  final cookies = CookieVault();
  final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
  await store.init();
  final dio = Dio()..httpClientAdapter = _EmptyAdapter();
  final api = TiebaApi(
    device: TiebaDevice.ephemeral(),
    dio: dio,
    credentialProvider: () => (
      bduss: store.bduss,
      stoken: store.stoken,
      tbs: store.tbs,
      uid: store.activeUid ?? '',
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
  final chrome = ChromeController();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FrostedSettings>.value(value: settings),
      ChangeNotifierProvider<FrostedStore>.value(value: store),
      ChangeNotifierProvider<ChromeController>.value(value: chrome),
      Provider<TiebaRepo>.value(value: repo),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
      child: PrismApp(
        theme: frostedTheme(
          brightness: Brightness.dark,
          accentArgb: defaultAccent.toARGB32(),
          style: settings.colorStyle,
        ),
        liquidGlass: null,
        localizationsDelegates: FrostedUiLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        builder: (context, inner) => ViewScope(
          size: size,
          isMobile: true,
          child: BottomInsetScope(
            inset: NavigationDock.insetOf(context),
            child: inner ?? const SizedBox.shrink(),
          ),
        ),
        home: const MePage(),
      ),
    ),
  );
}

void main() {
  tearDown(() {
    TabSnapshotCache.instance.configureForTesting(null);
  });

  group('MePage 个人页面居中布局', () {
    testWidgets('已登录态在状态栏与底栏之间的可视区域内整体居中', (tester) async {
      TabSnapshotCache.instance.configureForTesting(() async => null);
      const viewportSize = Size(412, 915);
      const safePadding = EdgeInsets.only(top: 44, bottom: 24);
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildHost(
          loggedIn: true,
          size: viewportSize,
          padding: safePadding,
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = find.byKey(const ValueKey('me-page-content'));
      expect(contentFinder, findsOneWidget);

      final rect = tester.getRect(contentFinder);
      final element = tester.element(contentFinder);
      final dockInset = NavigationDock.insetOf(element);

      final topGap = rect.top - safePadding.top;
      final bottomGap = (viewportSize.height - dockInset) - rect.bottom;
      expect(topGap, greaterThan(16));
      expect((topGap - bottomGap).abs(), lessThanOrEqualTo(1.5));

      final leftGap = rect.left;
      final rightGap = viewportSize.width - rect.right;
      expect((leftGap - rightGap).abs(), lessThanOrEqualTo(1.5));
    });

    testWidgets('小屏/横屏内容超高时保持可滚动且宽屏下水平居中', (tester) async {
      TabSnapshotCache.instance.configureForTesting(() async => null);
      const viewportSize = Size(840, 460);
      const safePadding = EdgeInsets.only(top: 24, bottom: 16);
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildHost(
          loggedIn: true,
          size: viewportSize,
          padding: safePadding,
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = find.byKey(const ValueKey('me-page-content'));
      final rect = tester.getRect(contentFinder);
      expect(rect.width, lessThanOrEqualTo(560.5));
      expect(
        (rect.left - (viewportSize.width - rect.right)).abs(),
        lessThanOrEqualTo(1.5),
      );

      final scrollFinder = find.byKey(const ValueKey('me-page-scroll'));
      await tester.drag(scrollFinder, const Offset(0, -360));
      await tester.pumpAndSettle();
      expect(find.text('全部设置'), findsOneWidget);
      final lastItemRect = tester.getRect(find.text('全部设置'));
      expect(lastItemRect.bottom, lessThan(viewportSize.height));
    });

    testWidgets('游客态在顶栏与底栏之间的可视区域内整体居中', (tester) async {
      TabSnapshotCache.instance.configureForTesting(() async => null);
      const viewportSize = Size(412, 915);
      const safePadding = EdgeInsets.only(top: 44, bottom: 24);
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        await _buildHost(
          loggedIn: false,
          size: viewportSize,
          padding: safePadding,
        ),
      );
      await tester.pumpAndSettle();

      final contentFinder = find.byKey(const ValueKey('guest-me-page-content'));
      expect(contentFinder, findsOneWidget);

      final rect = tester.getRect(contentFinder);
      final element = tester.element(contentFinder);
      final topBarInset = element.appBarInset;
      final dockInset = NavigationDock.insetOf(element);

      final topGap = rect.top - topBarInset;
      final bottomGap = (viewportSize.height - dockInset) - rect.bottom;
      expect(topGap, greaterThan(16));
      expect((topGap - bottomGap).abs(), lessThanOrEqualTo(1.5));
    });
  });
}
