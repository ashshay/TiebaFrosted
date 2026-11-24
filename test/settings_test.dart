import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/app.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/cookie_vault.dart';
import 'package:tieba_frosted/data/local_db.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/repo.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/data/store.dart';
import 'package:tieba_frosted/data/updater.dart';
import 'package:tieba_frosted/ui/routes.dart';
import 'package:tieba_frosted/ui/theme.dart';

void main() {
  Future<FrostedSettings> bootApp(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    final settings = FrostedSettings(prefs);
    final db = LocalDb.inMemory();
    final cookies = CookieVault();
    final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
    await store.init();
    final dio = Dio()..httpClientAdapter = _EmptyAdapter();
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
    return settings;
  }

  testWidgets('SettingsHabitPage uses 动态默认页 and FeedPage honors it', (
    tester,
  ) async {
    final settings = await bootApp(tester);

    final navContext = tester.element(find.text('首页'));
    openSettingsHabit(navContext);
    await tester.pumpAndSettle();

    expect(find.text('动态默认页'), findsOneWidget);
    expect(find.text('启动默认页'), findsNothing);
    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('热榜'), findsOneWidget);

    await tester.tap(find.text('关注'));
    await tester.pumpAndSettle();
    expect(settings.defaultFeedTab, 1);

    // 整行点击与直接点 Switch 都只切换一次
    final beforeOrigin = settings.loadOriginImage;
    await tester.tap(find.text('默认加载原图'));
    await tester.pumpAndSettle();
    expect(settings.loadOriginImage, !beforeOrigin);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(settings.loadOriginImage, beforeOrigin);

    // 返回主壳后首次进入「动态」，直接落在「关注」分栏
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('动态'));
    await tester.pumpAndSettle();
    expect(find.text('登录后查看关注动态'), findsOneWidget);
  });

  testWidgets('SettingsThemePage controls all update theme and liquid glass', (
    tester,
  ) async {
    systemMonetLightSeed = const Color(0xFF7B61FF);
    systemMonetDarkSeed = const Color(0xFFD0BCFF);
    addTearDown(() {
      systemMonetLightSeed = null;
      systemMonetDarkSeed = null;
    });

    final settings = await bootApp(tester);

    final navContext = tester.element(find.text('首页'));
    openSettingsTheme(navContext);
    await tester.pumpAndSettle();

    // 1. 主题模式切换
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(settings.darkMode, 2);
    expect(
      Theme.of(tester.element(find.text('外观与液态玻璃'))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(settings.darkMode, 1);
    expect(
      Theme.of(tester.element(find.text('外观与液态玻璃'))).brightness,
      Brightness.light,
    );

    // 2. Monet 默认下切换 ColorStyle 也能实际改变 primary / surfaceContainer
    final softScheme = Theme.of(
      tester.element(find.text('外观与液态玻璃')),
    ).colorScheme;
    await tester.tap(find.text('配色风格 (ColorStyle)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('鲜明 (Vivid)'));
    await tester.pumpAndSettle();
    expect(settings.colorStyle, ColorStyle.vivid);
    final vividScheme = Theme.of(
      tester.element(find.text('外观与液态玻璃')),
    ).colorScheme;
    expect(vividScheme.primary, isNot(softScheme.primary));

    await tester.tap(find.text('配色风格 (ColorStyle)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('单色 (Monochrome)'));
    await tester.pumpAndSettle();
    expect(settings.colorStyle, ColorStyle.monochrome);

    // 3. 主题强调色切换
    await tester.tap(find.text('配色风格 (ColorStyle)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('鲜明 (Vivid)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('主题强调色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('翠绿'));
    await tester.pumpAndSettle();
    expect(settings.accentColor, 0xFF30D158);
    expect(find.text('翠绿'), findsOneWidget);

    // 4. 底栏液态玻璃三档切换并驱动 LiquidGlassScope
    await tester.tap(find.text('底栏液态玻璃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('超高'));
    await tester.pumpAndSettle();
    expect(settings.liquidGlass, LiquidGlassLevel.ultra);
    expect(
      LiquidGlassScope.of(tester.element(find.text('外观与液态玻璃'))),
      isTrue,
    );
    expect(
      LiquidGlassScope.qualityOf(tester.element(find.text('外观与液态玻璃'))),
      LiquidGlassQuality.ultra,
    );

    await tester.tap(find.text('底栏液态玻璃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(settings.liquidGlass, LiquidGlassLevel.off);
    expect(
      LiquidGlassScope.of(tester.element(find.text('外观与液态玻璃'))),
      isFalse,
    );

    // 5. 顶栏毛玻璃模糊：整行点击与直接点 Switch 均生效且不重复触发
    final beforeBlur = settings.blurEffects;
    await tester.tap(find.text('顶栏毛玻璃模糊'));
    await tester.pumpAndSettle();
    expect(settings.blurEffects, !beforeBlur);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(settings.blurEffects, beforeBlur);

    // 6. 全局字体缩放滑块与重置按钮
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(settings.fontScale, greaterThan(1.0));
    expect(find.text('重置 100%'), findsOneWidget);

    await tester.tap(find.text('重置 100%'));
    await tester.pumpAndSettle();
    expect(settings.fontScale, 1.0);
    expect(find.text('重置 100%'), findsNothing);
  });
}

class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(const [0x12, 0x00], 200);

  @override
  void close({bool force = false}) {}
}
