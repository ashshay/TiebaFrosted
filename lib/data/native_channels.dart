import 'dart:async';

import 'package:flutter/services.dart';

/// Android 原生 MethodChannel 桥接（Cookie、相册、系统浏览器、分享）。
abstract final class NativeChannels {
  static const _cookies = MethodChannel('frosted/cookies');
  static const _media = MethodChannel('frosted/media');
  static const _browser = MethodChannel('frosted/browser');
  static const _share = MethodChannel('frosted/share');
  static const _deepLink = EventChannel('frosted/deeplink');

  static Future<Map<String, String>> readCookies() async {
    try {
      final raw = await _cookies.invokeMapMethod<String, dynamic>('read');
      if (raw == null) return const {};
      return {
        for (final entry in raw.entries)
          if (entry.value != null && entry.value.toString().isNotEmpty)
            entry.key: entry.value.toString(),
      };
    } on MissingPluginException {
      return const {};
    } on PlatformException {
      return const {};
    }
  }

  static Future<String> readRawCookie({
    String url = 'https://tieba.baidu.com',
  }) async {
    try {
      return await _cookies.invokeMethod<String>('readRaw', {'url': url}) ?? '';
    } on MissingPluginException {
      return '';
    } on PlatformException {
      return '';
    }
  }

  /// 只取贴吧域名下的 Cookie（等价于 TiebaLite 的
  /// `CookieManager.getCookie("https://tieba.baidu.com")`）。
  ///
  /// 贴吧写接口认的是贴吧域名的 `STOKEN`；passport / wappass 域名下也种了同名
  /// Cookie，那是网页登录凭证，混进来就会拿到错的那一份——表现为帖子能看、
  /// 收藏和回帖全被服务端判成未登录。
  static Future<Map<String, String>> readTiebaCookies() async {
    final raw = await readRawCookie(url: 'https://tieba.baidu.com');
    if (raw.isEmpty) return const {};
    final map = <String, String>{};
    for (final part in raw.split(';')) {
      final trimmed = part.trim();
      final idx = trimmed.indexOf('=');
      if (idx <= 0) continue;
      final key = trimmed.substring(0, idx).trim();
      final value = trimmed.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) map[key] = value;
    }
    return map;
  }

  static Future<void> injectCookies(Map<String, String> cookies) async {
    try {
      await _cookies.invokeMethod<void>('inject', {'cookies': cookies});
    } on MissingPluginException {
      // 非 Android 环境静默忽略
    } on PlatformException {
      // 忽略
    }
  }

  static Future<void> clearCookies() async {
    try {
      await _cookies.invokeMethod<void>('clear');
    } on MissingPluginException {
      // 忽略
    } on PlatformException {
      // 忽略
    }
  }

  static Future<String> saveImage(Uint8List bytes, {required String name}) async {
    final uri = await _media.invokeMethod<String>('saveImage', {
      'bytes': bytes,
      'name': name,
    });
    if (uri == null || uri.isEmpty) {
      throw StateError('保存图片失败');
    }
    return uri;
  }

  static Future<String> saveVideo(
    String path, {
    required String name,
    String mime = 'video/mp4',
  }) async {
    final uri = await _media.invokeMethod<String>('saveVideo', {
      'path': path,
      'name': name,
      'mime': mime,
    });
    if (uri == null || uri.isEmpty) {
      throw StateError('保存视频失败');
    }
    return uri;
  }

  static Future<bool> openInBrowser(String url) async {
    try {
      return await _browser.invokeMethod<bool>('open', {'url': url}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String?> consumeInitialDeepLink() async {
    try {
      return await _browser.invokeMethod<String>('initialLink');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 热启动时 onNewIntent 送来的链接流（app 已在前台又收到 VIEW intent）。
  static Stream<String> deepLinks() => _deepLink
      .receiveBroadcastStream()
      .map((event) => event?.toString() ?? '')
      .where((link) => link.isNotEmpty)
      .handleError((Object _) {});

  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      return await _share.invokeMethod<bool>('shareText', {
            'text': text,
            'subject': subject,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> shareImage(
    Uint8List bytes, {
    required String name,
  }) async {
    final ok = await _share.invokeMethod<bool>('shareImage', {
      'bytes': bytes,
      'name': name,
    });
    return ok ?? false;
  }
}
