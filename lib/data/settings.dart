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

  /// 启动时停在底栏哪一格：0 首页 / 1 动态 / 2 消息 / 3 我的。
  int startTab = 0;

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
    startTab = (_prefs.getInt('start_tab') ?? 0).clamp(0, 3);

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
    darkMode = value;
    await _prefs.setInt('dark_mode', value);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    accentColor = value;
    await _prefs.setInt('accent_color', value);
    notifyListeners();
  }

  Future<void> setColorStyle(ColorStyle value) async {
    colorStyle = value;
    await _prefs.setInt('color_style', value.index);
    notifyListeners();
  }

  Future<void> setLiquidGlass(LiquidGlassLevel value) async {
    liquidGlass = value;
    await _prefs.setInt('liquid_glass', value.index);
    notifyListeners();
  }

  Future<void> setBlurEffects(bool value) async {
    blurEffects = value;
    await _prefs.setBool('blur_effects', value);
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(0.85, 1.3);
    await _prefs.setDouble('font_scale', fontScale);
    notifyListeners();
  }

  Future<void> setLoadOriginImage(bool value) async {
    loadOriginImage = value;
    await _prefs.setBool('load_origin_image', value);
    notifyListeners();
  }

  Future<void> setShowBothUsernameAndNickname(bool value) async {
    showBothUsernameAndNickname = value;
    await _prefs.setBool('show_both_username_and_nickname', value);
    notifyListeners();
  }

  Future<void> setShowThreadAbstract(bool value) async {
    showThreadAbstract = value;
    await _prefs.setBool('show_thread_abstract', value);
    notifyListeners();
  }

  Future<void> setShowSingleLineTitle(bool value) async {
    showSingleLineTitle = value;
    await _prefs.setBool('show_single_line_title', value);
    notifyListeners();
  }

  Future<void> setConfirmBeforeLike(bool value) async {
    confirmBeforeLike = value;
    await _prefs.setBool('confirm_before_like', value);
    notifyListeners();
  }

  Future<void> setQuickSwitchAccount(bool value) async {
    quickSwitchAccount = value;
    await _prefs.setBool('quick_switch_account', value);
    notifyListeners();
  }

  Future<void> setProfileTabAvatar(bool value) async {
    profileTabAvatar = value;
    await _prefs.setBool('profile_tab_avatar', value);
    notifyListeners();
  }

  Future<void> setHideReply(bool value) async {
    hideReply = value;
    await _prefs.setBool('hide_reply', value);
    notifyListeners();
  }

  Future<void> setHideMedia(bool value) async {
    hideMedia = value;
    await _prefs.setBool('hide_media', value);
    notifyListeners();
  }

  Future<void> setForumListSingle(bool value) async {
    forumListSingle = value;
    await _prefs.setBool('forum_list_single', value);
    notifyListeners();
  }

  Future<void> setStartTab(int value) async {
    startTab = value.clamp(0, 3);
    await _prefs.setInt('start_tab', startTab);
    notifyListeners();
  }

  Future<void> setEnableBlock(bool value) async {
    enableBlock = value;
    await _prefs.setBool('enable_block', value);
    notifyListeners();
  }

  Future<void> setBlockVideoThread(bool value) async {
    blockVideoThread = value;
    await _prefs.setBool('block_video_thread', value);
    notifyListeners();
  }

  Future<void> setAutoSign(bool value) async {
    autoSign = value;
    await _prefs.setBool('auto_sign', value);
    notifyListeners();
  }

  Future<void> setAutoSignTime(int hour, int minute) async {
    autoSignHour = hour.clamp(0, 23);
    autoSignMinute = minute.clamp(0, 59);
    await _prefs.setInt('auto_sign_hour', autoSignHour);
    await _prefs.setInt('auto_sign_minute', autoSignMinute);
    notifyListeners();
  }

  Future<void> setOkSignUseOfficial(bool value) async {
    okSignUseOfficial = value;
    await _prefs.setBool('oksign_use_official', value);
    notifyListeners();
  }

  Future<void> setDefaultSortType(int value) async {
    defaultSortType = value.clamp(0, 1);
    await _prefs.setInt('default_sort_type', defaultSortType);
    notifyListeners();
  }

  Future<void> setFeedAnchor(String value) async {
    feedAnchor = value;
    await _prefs.setString('feed_anchor', value);
  }

  Future<void> setUseHttps(bool value) async {
    useHttps = value;
    await _prefs.setBool('use_https', value);
    notifyListeners();
  }
}
