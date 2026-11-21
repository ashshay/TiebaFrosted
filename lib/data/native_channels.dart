import 'package:flutter/services.dart';

/// Android 原生 MethodChannel 桥接（Cookie、相册、系统浏览器、分享）。
abstract final class NativeChannels {
  static const _cookies = MethodChannel('frosted/cookies');
  static const _media = MethodChannel('frosted/media');
  static const _browser = MethodChannel('frosted/browser');
  static const _share = MethodChannel('frosted/share');

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
}
