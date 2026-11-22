import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'image_cache.dart';
import 'native_channels.dart';

/// 图片与视频保存到系统相册（经由 Android MediaStore 通道）。
class MediaSaver {
  MediaSaver(this._dio);

  final Dio _dio;

  Future<String> saveImageFromUrl(String url) async {
    final normalized = normalizeTiebaImageUrl(url);
    Uint8List bytes;
    try {
      bytes = await TiebaImageCache.instance.getBytes(normalized);
    } on Object {
      final resp = await _dio.get<List<int>>(
        normalized,
        options: Options(
          responseType: ResponseType.bytes,
          headers: tiebaImageHeaders,
        ),
      );
      bytes = Uint8List.fromList(resp.data ?? const []);
    }
    if (bytes.isEmpty) throw StateError('下载图片为空');
    final ext = _guessExt(normalized, defaultExt: 'jpg');
    final name = 'tiebafrosted_${DateTime.now().millisecondsSinceEpoch}.$ext';
    return NativeChannels.saveImage(bytes, name: name);
  }

  Future<String> saveVideoFromUrl(String url) async {
    final normalized = url.startsWith('//') ? 'https:$url' : url;
    final dir = await getTemporaryDirectory();
    final name = 'tiebafrosted_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final file = File('${dir.path}/$name');
    try {
      await _dio.download(
        normalized,
        file.path,
        options: Options(
          headers: const {
            'User-Agent': 'bdtb for Android 12.64.1.1',
            'Referer': 'https://tieba.baidu.com/',
          },
        ),
      );
      return await NativeChannels.saveVideo(file.path, name: name);
    } finally {
      if (await file.exists()) {
        try {
          await file.delete();
        } on Object {
          // 忽略临时文件清理异常
        }
      }
    }
  }

  String _guessExt(String url, {required String defaultExt}) {
    final lower = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) return 'jpg';
    return defaultExt;
  }
}
