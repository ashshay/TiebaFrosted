import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:provider/provider.dart';

import 'data/local_db.dart';
import 'data/media_saver.dart';
import 'data/repo.dart';
import 'data/settings.dart';
import 'data/store.dart';
import 'ui/chrome.dart';
import 'ui/localizations.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class _FrostedScrollBehavior extends ScrollBehavior {
  const _FrostedScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

class TiebaFrostedApp extends StatefulWidget {
  const TiebaFrostedApp({
    super.key,
    required this.settings,
    required this.store,
    required this.db,
    required this.mediaSaver,
    required this.repo,
  });

  final FrostedSettings settings;
  final FrostedStore store;
  final LocalDb db;
  final MediaSaver mediaSaver;
  final TiebaRepo repo;

  @override
  State<TiebaFrostedApp> createState() => _TiebaFrostedAppState();
}

class _TiebaFrostedAppState extends State<TiebaFrostedApp> {
  final Map<String, ThemeData> _themes = {};
  Timer? _hueTimer;
  Color? _monetLight;
  Color? _monetDark;

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_syncHueTimer);
    _syncHueTimer();
    unawaited(_loadMonet());
  }

  Future<void> _loadMonet() async {
    try {
      final seeds = await DynamicColorPlugin.getSystemSeeds();
      if (!mounted || seeds == null) return;
      setState(() {
        _monetLight = seeds.light;
        _monetDark = seeds.dark;
      });
    } on Object {
      // 非 Android 12+ 设备回退默认贴吧蓝
    }
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncHueTimer);
    _hueTimer?.cancel();
    super.dispose();
  }

  void _syncHueTimer() {
    final cycling = widget.settings.accentColor == accentHueCycle;
    if (cycling && _hueTimer == null) {
      _hueTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
        if (mounted) setState(() {});
      });
    } else if (!cycling && _hueTimer != null) {
      _hueTimer?.cancel();
      _hueTimer = null;
    }
  }

  ThemeData _themeFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final configured = widget.settings.accentColor;
    final monet = dark ? _monetDark : _monetLight;
    final argb = configured == 0 && monet != null
        ? monet.toARGB32()
        : accentArgbAt(configured, dark: dark);
    final style = widget.settings.colorStyle;
    final key =
        '${brightness.name}-$argb-${style.index}-${widget.settings.fontScale}';
    return _themes.putIfAbsent(
      key,
      () => frostedTheme(
        brightness: brightness,
        accentArgb: argb,
        style: style,
        exactAccent: configured == 0 ? monet : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalDb>.value(value: widget.db),
        Provider<MediaSaver>.value(value: widget.mediaSaver),
        Provider<TiebaRepo>.value(value: widget.repo),
        ChangeNotifierProvider<FrostedSettings>.value(value: widget.settings),
        ChangeNotifierProvider<FrostedStore>.value(value: widget.store),
        ChangeNotifierProvider<ChromeController>(
          create: (_) => ChromeController(),
        ),
      ],
      child: Consumer<FrostedSettings>(
        builder: (context, settings, _) {
          final themeMode = switch (settings.darkMode) {
            1 => ThemeMode.light,
            2 => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return PrismApp(
            title: 'TiebaFrosted',
            debugShowCheckedModeBanner: false,
            theme: _themeFor(Brightness.light),
            darkTheme: _themeFor(Brightness.dark),
            themeMode: themeMode,
            textScale: settings.fontScale,
            minTextScale: 0.85,
            maxTextScale: 1.3,
            liquidGlass: settings.liquidGlassQuality,
            localizationsDelegates: FrostedUiLocalizations.delegates,
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            builder: (context, child) => ScrollConfiguration(
              behavior: const _FrostedScrollBehavior(),
              child: ViewScope(
                size: MediaQuery.sizeOf(context),
                isMobile: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const FrostedShell(),
          );
        },
      ),
    );
  }
}
