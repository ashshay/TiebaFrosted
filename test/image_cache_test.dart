import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/data/image_cache.dart';

void main() {
  group('TiebaImageCache', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tieba_img_cache_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('quantizeImageCacheWidth buckets small & medium sizes cleanly', () {
      expect(quantizeImageCacheWidth(64), 160);
      expect(quantizeImageCacheWidth(132), 160);
      expect(quantizeImageCacheWidth(160), 160);
      expect(quantizeImageCacheWidth(186), 320);
      expect(quantizeImageCacheWidth(480), 540);
      expect(quantizeImageCacheWidth(720), 768);
      expect(quantizeImageCacheWidth(1080), 1080);
      expect(quantizeImageCacheWidth(2400), 1440);
    });

    test('deduplicates concurrent in-flight requests and persists to disk', () async {
      var requests = 0;
      final gate = Completer<void>();
      final payload = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4]);
      final dio = Dio()
        ..httpClientAdapter = _FakeImageAdapter((options) async {
          requests++;
          await gate.future;
          return ResponseBody.fromBytes(payload, 200);
        });

      final cache1 = TiebaImageCache(
        dio: dio,
        cacheDirProvider: () async => tempDir,
      );

      final f1 = cache1.getBytes('https://img.example.com/a.png');
      final f2 = cache1.getBytes('https://img.example.com/a.png');
      final f3 = cache1.getBytes('//img.example.com/a.png');
      gate.complete();

      final results = await Future.wait([f1, f2, f3]);
      expect(requests, 1);
      for (final bytes in results) {
        expect(bytes, payload);
      }

      // 等待异步落盘完成，再用一个全新的缓存实例模拟冷启动后读盘命中（0 网络请求）
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final cache2 = TiebaImageCache(
        dio: dio,
        cacheDirProvider: () async => tempDir,
      );
      final fromDisk = await cache2.getBytes('https://img.example.com/a.png');
      expect(fromDisk, payload);
      expect(requests, 1);
      expect(await cache2.diskUsageBytes(), payload.length);

      await cache2.clear(includeFlutterImageCache: false);
      expect(await cache2.diskUsageBytes(), 0);
    });

    test('falls back without Referer and remembers the host/URL', () async {
      final seenReferers = <String?>[];
      final payload = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 9, 8, 7]);
      final dio = Dio()
        ..httpClientAdapter = _FakeImageAdapter((options) async {
          final referer = options.headers['Referer']?.toString();
          seenReferers.add(referer);
          if (referer != null) {
            // 模拟防盗链 403
            return ResponseBody.fromBytes(const [], 403);
          }
          return ResponseBody.fromBytes(payload, 200);
        });

      final cache = TiebaImageCache(
        dio: dio,
        cacheDirProvider: () async => null,
        maxMemoryBytes: 0, // 禁用内存命中以验证二次请求是否直接跳过 Referer
      );

      final first = await cache.getBytes('https://cdn.example.com/pic.jpg');
      expect(first, payload);
      expect(seenReferers, ['https://tieba.baidu.com/', null]);

      final second = await cache.getBytes('https://cdn.example.com/pic.jpg');
      expect(second, payload);
      // 第二次应直接发无 Referer 请求，不再多一次 403 往返
      expect(seenReferers, ['https://tieba.baidu.com/', null, null]);
    });

    test('rejects HTML error page responses and retries without Referer', () async {
      final htmlBytes = Uint8List.fromList('<!DOCTYPE html><html>403</html>'.codeUnits);
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 42]);
      final dio = Dio()
        ..httpClientAdapter = _FakeImageAdapter((options) async {
          if (options.headers['Referer'] != null) {
            return ResponseBody.fromBytes(htmlBytes, 200);
          }
          return ResponseBody.fromBytes(pngBytes, 200);
        });

      final cache = TiebaImageCache(
        dio: dio,
        cacheDirProvider: () async => null,
      );
      final bytes = await cache.getBytes('https://cdn.example.com/html_trap.png');
      expect(bytes, pngBytes);
    });

    test('trims oldest disk cache files when exceeding maxDiskBytes', () async {
      final payload = Uint8List(40);
      final dio = Dio()
        ..httpClientAdapter = _FakeImageAdapter((_) async {
          return ResponseBody.fromBytes(payload, 200);
        });

      final cache = TiebaImageCache(
        dio: dio,
        cacheDirProvider: () async => tempDir,
        maxDiskBytes: 100,
        maxDiskFiles: 10,
      );

      for (var i = 0; i < 4; i++) {
        await cache.getBytes('https://img.example.com/item_$i.jpg');
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      await cache.trimDiskCache();
      final usage = await cache.diskUsageBytes();
      expect(usage, lessThanOrEqualTo(100));
    });

    testWidgets(
      'TiebaCachedImageProvider decodes and renders a real PNG without error',
      (tester) async {
        // 标准合法 1x1 红色 PNG 字节
        final validPng = Uint8List.fromList(const [
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
          0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
          0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
          0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
          0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
          0x44, 0xAE, 0x42, 0x60, 0x82,
        ]);
        var fetches = 0;
        final dio = Dio()
          ..httpClientAdapter = _FakeImageAdapter((_) async {
            fetches++;
            return ResponseBody.fromBytes(validPng, 200);
          });
        final cache = TiebaImageCache(
          dio: dio,
          cacheDirProvider: () async => tempDir,
        );

        var errored = false;
        var renderedFrames = 0;

        await tester.runAsync(() async {
          final completer = Completer<ImageInfo>();
          final provider = TiebaCachedImageProvider(
            'https://img.example.com/pixel.png',
            cacheWidth: 160,
            cache: cache,
          );
          final stream = provider.resolve(ImageConfiguration.empty);
          late ImageStreamListener listener;
          listener = ImageStreamListener(
            (info, _) {
              renderedFrames++;
              if (!completer.isCompleted) completer.complete(info);
            },
            onError: (e, st) {
              errored = true;
              if (!completer.isCompleted) completer.completeError(e, st);
            },
          );
          stream.addListener(listener);
          final info = await completer.future;
          expect(info.image.width, 1);
          expect(info.image.height, 1);
          info.dispose();
          stream.removeListener(listener);
        });

        expect(errored, isFalse);
        expect(renderedFrames, 1);
        expect(fetches, 1);
      },
    );
  });
}

class _FakeImageAdapter implements HttpClientAdapter {
  _FakeImageAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}
