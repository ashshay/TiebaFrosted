import 'package:flutter/foundation.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 特殊强调色值：跟随色相缓慢循环。
const int accentHueCycle = -1;

/// 液态玻璃档位（关 / 标准 / 超高）。
enum LiquidGlassLevel { off, standard, ultra }

/// TiebaFrosted 全部设置项（SharedPreferences + ChangeNotifier）。
class FrostedSettings extends ChangeNotifier {
  FrostedSettings(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  // 外观
  int darkMode = 0; // 0 跟随系统 / 1 浅色 / 2 深色
  int accentColor = 0; // 0 跟随壁纸 Monet / ARGB / -1 色相循环
  ColorStyle colorStyle = ColorStyle.soft; // vivid / tinted / soft / monochrome
  LiquidGlassLevel liquidGlass = LiquidGlassLevel.standard;
  bool blurEffects = true;
  double fontScale = 1.0;

  // 浏览与交互习惯
  bool loadOriginImage = false;
  bool showBothUsernameAndNickname = false;
  bool showThreadAbstract = true;
  bool showSingleLineTitle = false;
  bool hideForumSortTip = false;
  bool confirmBeforeLike = false;
  bool quickSwitchAccount = true;
  bool profileTabAvatar = true;
  bool hideReply = false;
  bool hideMedia = false;
  /// 「进吧」页排列：false 为多列网格（原版默认），true 为单列列表。
  bool forumListSingle = false;

  /// 动态页左右滑动切换「推荐 / 关注 / 热榜」。
  bool swipeSwitchFeed = true;

  /// 首页顶部显示「经过贴吧」横滑条。
  bool homeShowHistoryForum = true;

  /// 站外链接一律用内置浏览器打开；关掉后交给系统浏览器。
  bool useWebView = true;

  /// 启动时停在底栏哪一格：0 首页 / 1 动态 / 2 消息 / 3 我的。
  int startTab = 0;

  /// 进入「动态」时默认停在哪个分栏：0 推荐 / 1 关注 / 2 热榜。
  int defaultFeedTab = 0;

  // 屏蔽总开关
  bool enableBlock = true;
  bool blockVideoThread = false;

  // 自动签到
  bool autoSign = false;
  int autoSignHour = 9;
  int autoSignMinute = 0;
  bool okSignUseOfficial = true;

  // 自定义与杂项
  int defaultSortType = 0; // 0 按回复时间 / 1 按发帖时间
  String feedAnchor = '';
  bool useHttps = true;

  LiquidGlassQuality? get liquidGlassQuality => switch (liquidGlass) {
    LiquidGlassLevel.off => null,
    LiquidGlassLevel.standard => LiquidGlassQuality.standard,
    LiquidGlassLevel.ultra => LiquidGlassQuality.ultra,
  };

  void _load() {
    darkMode = _prefs.getInt('dark_mode') ?? 0;
    accentColor = _prefs.getInt('accent_color') ?? 0;
    final styleIdx = _prefs.getInt('color_style') ?? ColorStyle.soft.index;
    colorStyle = ColorStyle.values[styleIdx.clamp(0, ColorStyle.values.length - 1)];
    final glassIdx =
        _prefs.getInt('liquid_glass') ?? LiquidGlassLevel.standard.index;
    liquidGlass = LiquidGlassLevel
        .values[glassIdx.clamp(0, LiquidGlassLevel.values.length - 1)];
    blurEffects = _prefs.getBool('blur_effects') ?? true;
    fontScale = (_prefs.getDouble('font_scale') ?? 1.0).clamp(0.85, 1.3);

    loadOriginImage = _prefs.getBool('load_origin_image') ?? false;
    showBothUsernameAndNickname =
        _prefs.getBool('show_both_username_and_nickname') ?? false;
    showThreadAbstract = _prefs.getBool('show_thread_abstract') ?? true;
    showSingleLineTitle = _prefs.getBool('show_single_line_title') ?? false;
    hideForumSortTip = _prefs.getBool('hide_forum_sort_tip') ?? false;
    confirmBeforeLike = _prefs.getBool('confirm_before_like') ?? false;
    quickSwitchAccount = _prefs.getBool('quick_switch_account') ?? true;
    profileTabAvatar = _prefs.getBool('profile_tab_avatar') ?? true;
    hideReply = _prefs.getBool('hide_reply') ?? false;
    hideMedia = _prefs.getBool('hide_media') ?? false;
    forumListSingle = _prefs.getBool('forum_list_single') ?? false;
    swipeSwitchFeed = _prefs.getBool('swipe_switch_feed') ?? true;
    homeShowHistoryForum = _prefs.getBool('home_show_history_forum') ?? true;
    useWebView = _prefs.getBool('use_webview') ?? true;
    startTab = (_prefs.getInt('start_tab') ?? 0).clamp(0, 3);
    defaultFeedTab = (_prefs.getInt('default_feed_tab') ?? 0).clamp(0, 2);

    enableBlock = _prefs.getBool('enable_block') ?? true;
    blockVideoThread = _prefs.getBool('block_video_thread') ?? false;

    autoSign = _prefs.getBool('auto_sign') ?? false;
    autoSignHour = (_prefs.getInt('auto_sign_hour') ?? 9).clamp(0, 23);
    autoSignMinute = (_prefs.getInt('auto_sign_minute') ?? 0).clamp(0, 59);
    okSignUseOfficial = _prefs.getBool('oksign_use_official') ?? true;

    defaultSortType = (_prefs.getInt('default_sort_type') ?? 0).clamp(0, 1);
    feedAnchor = _prefs.getString('feed_anchor') ?? '';
    useHttps = _prefs.getBool('use_https') ?? true;
  }

  Future<void> setDarkMode(int value) async {
    if (darkMode == value) return;
    darkMode = value;
    notifyListeners();
    await _prefs.setInt('dark_mode', value);
  }

  Future<void> setAccentColor(int value) async {
    if (accentColor == value) return;
    accentColor = value;
    notifyListeners();
    await _prefs.setInt('accent_color', value);
  }

  Future<void> setColorStyle(ColorStyle value) async {
    if (colorStyle == value) return;
    colorStyle = value;
    notifyListeners();
    await _prefs.setInt('color_style', value.index);
  }

  Future<void> setLiquidGlass(LiquidGlassLevel value) async {
    if (liquidGlass == value) return;
    liquidGlass = value;
    notifyListeners();
    await _prefs.setInt('liquid_glass', value.index);
  }

  Future<void> setBlurEffects(bool value) async {
    if (blurEffects == value) return;
    blurEffects = value;
    notifyListeners();
    await _prefs.setBool('blur_effects', value);
  }

  Future<void> setFontScale(double value) async {
    final next = (value.clamp(0.85, 1.3) * 100).round() / 100.0;
    if (fontScale == next) return;
    fontScale = next;
    notifyListeners();
    await _prefs.setDouble('font_scale', fontScale);
  }

  Future<void> setLoadOriginImage(bool value) async {
    if (loadOriginImage == value) return;
    loadOriginImage = value;
    notifyListeners();
    await _prefs.setBool('load_origin_image', value);
  }

  Future<void> setShowBothUsernameAndNickname(bool value) async {
    if (showBothUsernameAndNickname == value) return;
    showBothUsernameAndNickname = value;
    notifyListeners();
    await _prefs.setBool('show_both_username_and_nickname', value);
  }

  Future<void> setShowThreadAbstract(bool value) async {
    if (showThreadAbstract == value) return;
    showThreadAbstract = value;
    notifyListeners();
    await _prefs.setBool('show_thread_abstract', value);
  }

  Future<void> setShowSingleLineTitle(bool value) async {
    if (showSingleLineTitle == value) return;
    showSingleLineTitle = value;
    notifyListeners();
    await _prefs.setBool('show_single_line_title', value);
  }

  Future<void> setConfirmBeforeLike(bool value) async {
    if (confirmBeforeLike == value) return;
    confirmBeforeLike = value;
    notifyListeners();
    await _prefs.setBool('confirm_before_like', value);
  }

  Future<void> setQuickSwitchAccount(bool value) async {
    if (quickSwitchAccount == value) return;
    quickSwitchAccount = value;
    notifyListeners();
    await _prefs.setBool('quick_switch_account', value);
  }

  Future<void> setProfileTabAvatar(bool value) async {
    if (profileTabAvatar == value) return;
    profileTabAvatar = value;
    notifyListeners();
    await _prefs.setBool('profile_tab_avatar', value);
  }

  Future<void> setHideReply(bool value) async {
    if (hideReply == value) return;
    hideReply = value;
    notifyListeners();
    await _prefs.setBool('hide_reply', value);
  }

  Future<void> setHideMedia(bool value) async {
    if (hideMedia == value) return;
    hideMedia = value;
    notifyListeners();
    await _prefs.setBool('hide_media', value);
  }

  Future<void> setForumListSingle(bool value) async {
    if (forumListSingle == value) return;
    forumListSingle = value;
    notifyListeners();
    await _prefs.setBool('forum_list_single', value);
  }

  Future<void> setSwipeSwitchFeed(bool value) async {
    if (swipeSwitchFeed == value) return;
    swipeSwitchFeed = value;
    notifyListeners();
    await _prefs.setBool('swipe_switch_feed', value);
  }

  Future<void> setHomeShowHistoryForum(bool value) async {
    if (homeShowHistoryForum == value) return;
    homeShowHistoryForum = value;
    notifyListeners();
    await _prefs.setBool('home_show_history_forum', value);
  }

  Future<void> setUseWebView(bool value) async {
    if (useWebView == value) return;
    useWebView = value;
    notifyListeners();
    await _prefs.setBool('use_webview', value);
  }

  Future<void> setStartTab(int value) async {
    final next = value.clamp(0, 3);
    if (startTab == next) return;
    startTab = next;
    notifyListeners();
    await _prefs.setInt('start_tab', startTab);
  }

  Future<void> setDefaultFeedTab(int value) async {
    final next = value.clamp(0, 2);
    if (defaultFeedTab == next) return;
    defaultFeedTab = next;
    notifyListeners();
    await _prefs.setInt('default_feed_tab', defaultFeedTab);
  }

  Future<void> setEnableBlock(bool value) async {
    if (enableBlock == value) return;
    enableBlock = value;
    notifyListeners();
    await _prefs.setBool('enable_block', value);
  }

  Future<void> setBlockVideoThread(bool value) async {
    if (blockVideoThread == value) return;
    blockVideoThread = value;
    notifyListeners();
    await _prefs.setBool('block_video_thread', value);
  }

  Future<void> setAutoSign(bool value) async {
    if (autoSign == value) return;
    autoSign = value;
    notifyListeners();
    await _prefs.setBool('auto_sign', value);
  }

  Future<void> setAutoSignTime(int hour, int minute) async {
    autoSignHour = hour.clamp(0, 23);
    autoSignMinute = minute.clamp(0, 59);
    notifyListeners();
    await _prefs.setInt('auto_sign_hour', autoSignHour);
    await _prefs.setInt('auto_sign_minute', autoSignMinute);
  }

  Future<void> setOkSignUseOfficial(bool value) async {
    if (okSignUseOfficial == value) return;
    okSignUseOfficial = value;
    notifyListeners();
    await _prefs.setBool('oksign_use_official', value);
  }

  Future<void> setDefaultSortType(int value) async {
    final next = value.clamp(0, 1);
    if (defaultSortType == next) return;
    defaultSortType = next;
    notifyListeners();
    await _prefs.setInt('default_sort_type', defaultSortType);
  }

  Future<void> setFeedAnchor(String value) async {
    feedAnchor = value;
    await _prefs.setString('feed_anchor', value);
  }

  Future<void> setUseHttps(bool value) async {
    if (useHttps == value) return;
    useHttps = value;
    notifyListeners();
    await _prefs.setBool('use_https', value);
  }
}
