import 'native_channels.dart';

/// 域名 → Cookie 键值对管理，支持 Set-Cookie 吸收与原生 WebView CookieManager 同步。
class CookieVault {
  final Map<String, String> _cookies = {};

  Map<String, String> get all => Map.unmodifiable(_cookies);

  String get bduss => _cookies['BDUSS'] ?? '';
  String get stoken => _cookies['STOKEN'] ?? '';
  String get baiduId => _cookies['BAIDUID'] ?? '';

  String get rawHeader {
    if (_cookies.isEmpty) return '';
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void loadFromMap(Map<String, String> map) {
    _cookies
      ..clear()
      ..addAll(map);
  }

  void loadFromRaw(String raw) {
    _cookies.clear();
    absorbRaw(raw);
  }

  void absorbRaw(String raw) {
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      final idx = trimmed.indexOf('=');
      if (idx <= 0) continue;
      final key = trimmed.substring(0, idx).trim();
      final val = trimmed.substring(idx + 1).trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        _cookies[key] = val;
      }
    }
  }

  void absorbSetCookies(List<String>? setCookies) {
    if (setCookies == null || setCookies.isEmpty) return;
    for (final line in setCookies) {
      final first = line.split(';').first.trim();
      final idx = first.indexOf('=');
      if (idx <= 0) continue;
      final key = first.substring(0, idx).trim();
      final val = first.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      if (val.isEmpty || val.toLowerCase() == 'deleted') {
        _cookies.remove(key);
      } else {
        _cookies[key] = val;
      }
    }
  }

  void set(String key, String value) {
    if (value.isEmpty) {
      _cookies.remove(key);
    } else {
      _cookies[key] = value;
    }
  }

  void clear() => _cookies.clear();

  Future<Map<String, String>> syncFromWebView() async {
    final map = await NativeChannels.readCookies();
    if (map.isNotEmpty) {
      _cookies.addAll(map);
    }
    return map;
  }

  Future<void> pushToWebView() async {
    if (_cookies.isEmpty) return;
    await NativeChannels.injectCookies(_cookies);
  }

  Future<void> clearWebView() async {
    await NativeChannels.clearCookies();
  }
}
