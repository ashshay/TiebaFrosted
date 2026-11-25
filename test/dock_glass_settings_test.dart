import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/ui/localizations.dart';
import 'package:tieba_frosted/ui/pages/dock_glass_settings_page.dart';
import 'package:tieba_frosted/ui/routes.dart';
import 'package:tieba_frosted/ui/theme.dart';

Widget _host(FrostedSettings settings, Widget child) {
  return ChangeNotifierProvider<FrostedSettings>.value(
    value: settings,
    child: Consumer<FrostedSettings>(
      builder: (context, s, _) => PrismApp(
        theme: frostedTheme(
          brightness: Brightness.light,
          accentArgb: accentArgbAt(0, dark: false),
          style: s.colorStyle,
        ),
        liquidGlass: s.liquidGlassQuality,
        localizationsDelegates: FrostedUiLocalizations.delegates,
        supportedLocales: const [Locale('zh', 'CN')],
        locale: const Locale('zh', 'CN'),
        builder: (context, inner) => ViewScope(
          size: MediaQuery.sizeOf(context),
          isMobile: true,
          child: inner ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    ),
  );
}

void main() {
  group('TiebaFrosted 底栏液态玻璃设置持久化', () {
    test('归一化、摘要与持久化重置', () async {
      expect(normalizeDockGlassAmount(-1.0), 0.0);
      expect(normalizeDockGlassAmount(0.454), 0.45);
      expect(normalizeDockGlassAmount(1.8), 1.0);
      expect(normalizeDockGlassAmount(double.nan), 0.0);

      expect(
        dockGlassSummary(
          glassEnabled: false,
          style: DockGlassPreset.crystal,
          frost: 0.2,
          refraction: 0.85,
        ),
        contains('已关闭'),
      );
      expect(
        dockGlassSummary(
          glassEnabled: true,
          style: DockGlassPreset.prism,
          frost: 0.2,
          refraction: 0.85,
        ),
        'Prism 磨砂',
      );
      expect(
        dockGlassSummary(
          glassEnabled: true,
          style: DockGlassPreset.crystal,
          frost: 0.2,
          refraction: 0.85,
        ),
        '清透液态 · 磨砂 20% · 折射 85%',
      );

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = FrostedSettings(prefs);
      expect(settings.dockGlassStyle, DockGlassPreset.prism);
      expect(settings.dockFrostAmount, 0.0);
      expect(settings.dockRefractionAmount, 1.0);

      settings
        ..applyDockGlassStyle(DockGlassPreset.crystal)
        ..applyDockFrostAmount(0.4)
        ..applyDockRefractionAmount(0.7);

      final reloaded = FrostedSettings(prefs);
      expect(reloaded.dockGlassStyle, DockGlassPreset.crystal);
      expect(reloaded.dockFrostAmount, 0.4);
      expect(reloaded.dockRefractionAmount, 0.7);
      expect(reloaded.navigationDockGlassStyle.isCrystal, isTrue);

      reloaded.resetDockGlass();
      expect(reloaded.dockGlassStyle, DockGlassPreset.prism);
      expect(reloaded.dockFrostAmount, 0.0);
      expect(reloaded.dockRefractionAmount, 1.0);
    });
  });

  group('TiebaFrosted DockGlassSettingsPage 预览、防误返与交互', () {
    testWidgets('风格切换、快捷预设、滑块微调、总开关联动与重置', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'liquid_glass': LiquidGlassLevel.off.index,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = FrostedSettings(prefs);

      await tester.pumpWidget(_host(settings, const DockGlassSettingsPage()));
      await tester.pumpAndSettle();

      // 液态玻璃关闭时内联露出快捷开启开关
      final toggle = find.byKey(const ValueKey('dock-glass-enable-switch'));
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.liquidGlass, LiquidGlassLevel.standard);
      expect(toggle, findsNothing);

      NavigationDock previewDock() => tester.widget<NavigationDock>(
        find.byKey(const ValueKey('dock-glass-preview-dock')),
      );

      expect(previewDock().glassStyle?.preset, DockGlassPreset.prism);
      expect(previewDock().tintSelection, isFalse);

      await tester.tap(find.byKey(const ValueKey('dock-glass-try-crystal')));
      await tester.pumpAndSettle();
      expect(settings.dockGlassStyle, DockGlassPreset.crystal);
      expect(previewDock().glassStyle?.isCrystal, isTrue);
      expect(previewDock().tintSelection, isTrue);

      await tester.tap(find.text('轻雾清透'));
      await tester.pumpAndSettle();
      expect(settings.dockFrostAmount, 0.2);
      expect(settings.dockRefractionAmount, 0.85);

      await tester.tap(find.text('磨砂'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('无折射'));
      await tester.pumpAndSettle();
      expect(settings.dockFrostAmount, 0.3);
      expect(settings.dockRefractionAmount, 0.75);

      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      expect(previewDock().selectedIndex, 2);

      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      expect(settings.dockGlassStyle, DockGlassPreset.prism);
      expect(settings.dockFrostAmount, 0.0);
      expect(settings.dockRefractionAmount, 1.0);
    });

    testWidgets('推入路由禁用侧滑返回且色卡可滚入底栏背后', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        'dock_glass_style': DockGlassPreset.crystal.index,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = FrostedSettings(prefs);

      await tester.pumpWidget(
        _host(
          settings,
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => openDockGlassSettings(context),
                child: const Text('打开底栏液态玻璃'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开底栏液态玻璃'));
      await tester.pumpAndSettle();
      expect(find.byType(DockGlassSettingsPage), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('dock-glass-preview-dock')),
        const Offset(240, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DockGlassSettingsPage), findsOneWidget);

      await tester.dragFrom(const Offset(40, 320), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(find.byType(DockGlassSettingsPage), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('dock-glass-preview-list')),
        const Offset(0, -480),
      );
      await tester.pumpAndSettle();
      final dockRect = tester.getRect(
        find.byKey(const ValueKey('dock-glass-preview-dock')),
      );
      final spectrumRect = tester.getRect(find.text('LIQUID GLASS'));
      expect(spectrumRect.top, lessThan(dockRect.bottom));
    });
  });
}
