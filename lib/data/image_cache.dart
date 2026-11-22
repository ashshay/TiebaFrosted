import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const Map<String, String> tiebaImageHeaders = {
  'User-Agent': 'bdtb for Android 12.64.1.1',
  'Referer': 'https://tieba.baidu.com/',
  'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
};

const Map<String, String> tiebaNoRefererHeaders = {
  'User-Agent': 'bdtb for Android 12.64.1.1',
  'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
};

String normalizeTiebaImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  return trimmed;
}

/// 将解码目标宽度量化到固定档位，避免同一 URL 因控件尺寸微小差异在
/// `ImageCache` 中分裂出多份缓存并触发重复解码。
int quantizeImageCacheWidth(int rawWidth) {
  if (rawWidth <= 160) return 160;
  if (rawWidth <= 320) return 320;
  if (rawWidth <= 540) return 540;
  if (rawWidth <= 768) return 768;
  if (rawWidth <= 1080) return 1080;
  return 1440;
}

bool looksAnimatedImageUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('.gif') || lower.contains('format=gif');
}

/// 统一二级图片缓存：
/// - L1: Flutter `PaintingBinding.instance.imageCache`（解码纹理，按量化宽度复用）
/// - L2: 进程内热字节 LRU（免除缩略图 -> 原尺寸重解码时的磁盘与网络 IO）
/// - L3: 本地磁盘 LRU（`tieba_image_cache/`，原子写入 + 后台容量裁剪）
/// - 并发请求合并（in-flight dedup）+ Referer 自动回退记忆。
class TiebaImageCache {
  TiebaImageCache({
    Dio? dio,
    Future<Directory?> Function()? cacheDirProvider,
    this.maxMemoryBytes = 16 * 1024 * 1024,
    this.maxSingleMemoryEntryBytes = 4 * 1024 * 1024,
    this.maxDiskBytes = 180 * 1024 * 1024,
    this.maxDiskFiles = 2500,
  }) : _dio = dio ?? _createDefaultDio(),
       _cacheDirProvider = cacheDirProvider;

  static final TiebaImageCache instance = TiebaImageCache();

  static Dio _createDefaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.bytes,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  final int maxMemoryBytes;
  final int maxSingleMemoryEntryBytes;
  final int maxDiskBytes;
  final int maxDiskFiles;

  Dio _dio;
  final Future<Directory?> Function()? _cacheDirProvider;

  final LinkedHashMap<String, Uint8List> _memBytes =
      LinkedHashMap<String, Uint8List>();
  int _currentMemoryBytes = 0;

  final Map<String, Future<Uint8List>> _inFlight = {};
  final LinkedHashSet<String> _noRefererUrls = LinkedHashSet<String>();

  Future<Directory?>? _dirFuture;
  int _writesSinceTrim = 0;
  DateTime? _lastTrimAt;
  bool _trimming = false;
  int _tmpSeq = 0;

  /// 允许在应用启动时替换底层 Dio（例如复用代理配置或测试注入）。
  void configure({Dio? dio}) {
    if (dio != null) _dio = dio;
  }

  /// 计算 URL 对应的稳定磁盘文件名（SHA-256 前 32 位）。
  static String cacheKeyForUrl(String normalizedUrl) {
    final digest = sha256.convert(utf8.encode(normalizedUrl));
    return digest.toString().substring(0, 32);
  }

  /// 同步查询内存热字节缓存（命中时自动续期 LRU）。
  Uint8List? peekMemoryBytes(String rawUrl) {
    final url = normalizeTiebaImageUrl(rawUrl);
    if (url.isEmpty) return null;
    final bytes = _memBytes.remove(url);
    if (bytes != null) {
      _memBytes[url] = bytes;
    }
    return bytes;
  }

  /// 判断 URL 是否已存在于内存字节缓存或磁盘缓存。
  Future<bool> hasCached(String rawUrl) async {
    final url = normalizeTiebaImageUrl(rawUrl);
    if (url.isEmpty) return false;
    if (_memBytes.containsKey(url)) return true;
    final file = await _fileForUrl(url);
    if (file == null) return false;
    return file.exists();
  }

  /// 获取图片原始字节：优先内存 LRU -> 磁盘缓存 -> 合并中的网络请求 -> 新下载。
  Future<Uint8List> getBytes(String rawUrl) {
    final url = normalizeTiebaImageUrl(rawUrl);
    if (url.isEmpty) {
      return Future<Uint8List>.error(StateError('图片地址为空'));
    }

    final memHit = peekMemoryBytes(url);
    if (memHit != null) {
      return SynchronousFuture<Uint8List>(memHit);
    }

    final existing = _inFlight[url];
    if (existing != null) return existing;

    final future = _resolveBytes(url);
    _inFlight[url] = future;
    future.whenComplete(() {
      if (identical(_inFlight[url], future)) {
        _inFlight.remove(url);
      }
    });
    return future;
  }

  /// 静默预拉取到内存/磁盘缓存（用于大图画廊相邻页预加载）。
  Future<void> prefetch(String rawUrl) async {
    final url = normalizeTiebaImageUrl(rawUrl);
    if (url.isEmpty) return;
    if (_memBytes.containsKey(url)) return;
    try {
      await getBytes(url);
    } on Object {
      // 预加载失败静默忽略，真正渲染时再走错误展示
    }
  }

  /// 统计磁盘图片缓存占用字节数。
  Future<int> diskUsageBytes() async {
    final dir = await _resolveCacheDir();
    if (dir == null || !await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.img')) {
          try {
            total += await entity.length();
          } on Object {
            // 忽略并发删除的文件
          }
        }
      }
    } on Object {
      return total;
    }
    return total;
  }

  /// 清理内存字节缓存、磁盘缓存以及（可选）Flutter 解码图内存缓存。
  Future<void> clear({bool includeFlutterImageCache = true}) async {
    _memBytes.clear();
    _currentMemoryBytes = 0;
    _noRefererUrls.clear();
    if (includeFlutterImageCache) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    final dir = await _resolveCacheDir();
    if (dir == null || !await dir.exists()) return;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          try {
            await entity.delete();
          } on Object {
            // 忽略单文件清理失败
          }
        }
      }
    } on Object {
      // 忽略目录遍历异常
    }
  }

  Future<Uint8List> _resolveBytes(String url) async {
    // 1. 检查磁盘缓存
    final file = await _fileForUrl(url);
    if (file != null) {
      try {
        if (await file.exists()) {
          final diskBytes = await file.readAsBytes();
          if (diskBytes.isNotEmpty && !_looksLikeHtmlError(diskBytes)) {
            _putMemory(url, diskBytes);
            unawaited(_touchFileIfStale(file));
            return diskBytes;
          }
          // 清理损坏或空缓存文件
          unawaited(_safeDelete(file));
        }
      } on Object {
        // 读盘异常时自动回退网络拉取
      }
    }

    // 2. 网络拉取（自动 Referer 回退并记住）
    final downloaded = await _downloadWithFallback(url);
    _putMemory(url, downloaded);
    if (file != null) {
      unawaited(_writeAtomic(file, downloaded));
    }
    return downloaded;
  }

  Future<Uint8List> _downloadWithFallback(String url) async {
    final skipReferer = _noRefererUrls.contains(url);
    if (!skipReferer) {
      final first = await _tryDownload(url, tiebaImageHeaders);
      if (first != null) return first;
      final retry = await _tryDownload(url, tiebaNoRefererHeaders);
      if (retry != null) {
        _rememberNoReferer(url);
        return retry;
      }
      throw StateError('加载图片失败');
    }

    final direct = await _tryDownload(url, tiebaNoRefererHeaders);
    if (direct != null) return direct;
    final withReferer = await _tryDownload(url, tiebaImageHeaders);
    if (withReferer != null) {
      _noRefererUrls.remove(url);
      return withReferer;
    }
    throw StateError('加载图片失败');
  }

  Future<Uint8List?> _tryDownload(
    String url,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final code = resp.statusCode ?? 0;
      if (code < 200 || code >= 300) return null;
      final data = resp.data;
      if (data == null || data.isEmpty) return null;
      final bytes = data is Uint8List ? data : Uint8List.fromList(data);
      if (_looksLikeHtmlError(bytes)) return null;
      return bytes;
    } on Object {
      return null;
    }
  }

  bool _looksLikeHtmlError(Uint8List bytes) {
    if (bytes.length < 5) return false;
    var i = 0;
    while (i < bytes.length && i < 16 && (bytes[i] == 0x20 || bytes[i] == 0x0A || bytes[i] == 0x0D || bytes[i] == 0x09)) {
      i++;
    }
    if (i + 5 > bytes.length) return false;
    if (bytes[i] != 0x3C) return false; // '<'
    final prefix = String.fromCharCodes(
      bytes.sublist(i, (i + 15).clamp(0, bytes.length)),
    ).toLowerCase();
    return prefix.startsWith('<!doctype') ||
        prefix.startsWith('<html') ||
        prefix.startsWith('<head') ||
        prefix.startsWith('<body') ||
        prefix.startsWith('<?xml');
  }

  void _rememberNoReferer(String url) {
    _noRefererUrls.remove(url);
    _noRefererUrls.add(url);
    while (_noRefererUrls.length > 512) {
      _noRefererUrls.remove(_noRefererUrls.first);
    }
  }

  void _putMemory(String url, Uint8List bytes) {
    if (bytes.length > maxSingleMemoryEntryBytes || maxMemoryBytes <= 0) return;
    final old = _memBytes.remove(url);
    if (old != null) _currentMemoryBytes -= old.length;
    _memBytes[url] = bytes;
    _currentMemoryBytes += bytes.length;
    while (_currentMemoryBytes > maxMemoryBytes && _memBytes.isNotEmpty) {
      final oldestKey = _memBytes.keys.first;
      final evicted = _memBytes.remove(oldestKey);
      if (evicted != null) _currentMemoryBytes -= evicted.length;
    }
  }

  Future<Directory?> _resolveCacheDir() {
    return _dirFuture ??= _initCacheDir();
  }

  Future<Directory?> _initCacheDir() async {
    try {
      final base = _cacheDirProvider != null
          ? await _cacheDirProvider()
          : await getTemporaryDirectory();
      if (base == null) return null;
      final dir = Directory(p.join(base.path, 'tieba_image_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } on Object {
      // 单元测试无 path_provider 插件时优雅退化为纯内存缓存
      return null;
    }
  }

  Future<File?> _fileForUrl(String normalizedUrl) async {
    final dir = await _resolveCacheDir();
    if (dir == null) return null;
    return File(p.join(dir.path, '${cacheKeyForUrl(normalizedUrl)}.img'));
  }

  Future<void> _writeAtomic(File target, Uint8List bytes) async {
    final tmp = File('${target.path}.${_tmpSeq++}.tmp');
    try {
      await tmp.writeAsBytes(bytes, flush: false);
      if (await target.exists()) {
        try {
          await target.delete();
        } on Object {
          // Windows 上 rename 覆盖偶发冲突，先删旧文件再改名
        }
      }
      await tmp.rename(target.path);
      _writesSinceTrim++;
      _maybeScheduleTrim();
    } on Object {
      unawaited(_safeDelete(tmp));
    }
  }

  Future<void> _touchFileIfStale(File file) async {
    try {
      final stat = await file.stat();
      final now = DateTime.now();
      if (now.difference(stat.modified) > const Duration(hours: 1)) {
        await file.setLastModified(now);
      }
    } on Object {
      // 忽略触摸失败
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // 忽略清理异常
    }
  }

  void _maybeScheduleTrim() {
    if (_trimming) return;
    final now = DateTime.now();
    if (_writesSinceTrim < 30 &&
        _lastTrimAt != null &&
        now.difference(_lastTrimAt!) < const Duration(seconds: 30)) {
      return;
    }
    _writesSinceTrim = 0;
    _lastTrimAt = now;
    unawaited(trimDiskCache());
  }

  /// 按 LRU 裁剪超额磁盘缓存（保留约 85% 上限避免频繁触发）。
  Future<void> trimDiskCache() async {
    if (_trimming) return;
    _trimming = true;
    try {
      final dir = await _resolveCacheDir();
      if (dir == null || !await dir.exists()) return;
      final entries = <({File file, int size, DateTime modified})>[];
      var totalSize = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.tmp')) {
          unawaited(_safeDelete(entity));
          continue;
        }
        if (!entity.path.endsWith('.img')) continue;
        try {
          final stat = await entity.stat();
          entries.add((
            file: entity,
            size: stat.size,
            modified: stat.modified,
          ));
          totalSize += stat.size;
        } on Object {
          // 忽略并发消失的文件
        }
      }
      if (totalSize <= maxDiskBytes && entries.length <= maxDiskFiles) return;

      entries.sort((a, b) => a.modified.compareTo(b.modified));
      final targetBytes = (maxDiskBytes * 0.85).round();
      final targetCount = (maxDiskFiles * 0.85).round();
      var remainingCount = entries.length;
      for (final item in entries) {
        if (totalSize <= targetBytes && remainingCount <= targetCount) break;
        await _safeDelete(item.file);
        totalSize -= item.size;
        remainingCount--;
      }
    } on Object {
      // 忽略后台裁剪异常
    } finally {
      _trimming = false;
    }
  }
}

/// 绑定 [TiebaImageCache] 的自定义 ImageProvider：
/// - L1 由 Flutter `ImageCache` 以 `(normalizedUrl, cacheWidth, scale)` 索引
/// - L2/L3 复用统一字节缓存，避免同一图因不同展示尺寸或重进页面反复发网。
@immutable
class TiebaCachedImageProvider extends ImageProvider<TiebaCachedImageProvider> {
  TiebaCachedImageProvider(
    String url, {
    this.cacheWidth,
    this.scale = 1.0,
    TiebaImageCache? cache,
  }) : url = normalizeTiebaImageUrl(url),
       _cache = cache ?? TiebaImageCache.instance;

  final String url;
  final int? cacheWidth;
  final double scale;
  final TiebaImageCache _cache;

  @override
  Future<TiebaCachedImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<TiebaCachedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    TiebaCachedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<TiebaCachedImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    TiebaCachedImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final bytes = await key._cache.getBytes(key.url);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final targetWidth = key.cacheWidth;
      // 注意：dart:ui 的 instantiateImageCodecWithSize 会接管并自动释放 buffer，
      // 调用方不能再次调用 buffer.dispose()，否则会抛出异常导致所有图片解码失败。
      return await decode(
        buffer,
        getTargetSize: targetWidth == null
            ? null
            : (int intrinsicWidth, int intrinsicHeight) {
                // 只降采样不放大，兼顾清晰度与显存占用
                if (intrinsicWidth > targetWidth) {
                  return ui.TargetImageSize(width: targetWidth);
                }
                return const ui.TargetImageSize();
              },
      );
    } on Object {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TiebaCachedImageProvider &&
        other.url == url &&
        other.cacheWidth == cacheWidth &&
        other.scale == scale &&
        identical(other._cache, _cache);
  }

  @override
  int get hashCode => Object.hash(url, cacheWidth, scale, identityHashCode(_cache));

  @override
  String toString() =>
      '${objectRuntimeType(this, 'TiebaCachedImageProvider')}("$url", cacheWidth: $cacheWidth)';
}

/// 将字节数格式化为易读体积字符串（如 `12.4 MB`）。
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
