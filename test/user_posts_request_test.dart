import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/core/proto_wire.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/proto_codec.dart';

Uint8List encode({required bool isThread}) =>
    TiebaProtoCodec.encodeUserPostRequest(
      device: TiebaDevice.ephemeral(),
      uid: 854707021,
      page: 1,
      isThread: isThread,
      bduss: 'BDUSS_abcdefghij',
      stoken: 'STOKEN_abcdefghij',
      tbs: 'tbs_value',
    );

/// 前 [emptyCalls] 次回空列表，之后回一条；用于验证「回复」形状探测。
class _ShapeAdapter implements HttpClientAdapter {
  _ShapeAdapter({required this.emptyCalls});

  int emptyCalls;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    // data 字段里放一条空的 post_list 条目，或有 data 但无条目。
    final bytes = calls <= emptyCalls
        ? const [0x12, 0x00]
        : const [0x12, 0x02, 0x0A, 0x00];
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

TiebaApi _api(HttpClientAdapter adapter) => TiebaApi(
  device: TiebaDevice.ephemeral(),
  dio: Dio()..httpClientAdapter = adapter,
  credentialProvider: () => (
    bduss: 'BDUSS_abcdefghij',
    stoken: 'STOKEN_abcdefghij',
    tbs: 'tbs_value',
    uid: '854707021',
    zid: '',
    webCookie: '',
  ),
);

void main() {
  group('用户帖子 / 回复列表请求', () {
    test('「回复」列表默认形状不带 stoken', () {
      final replies = latin1.decode(encode(isThread: false), allowInvalid: true);
      expect(replies, isNot(contains('STOKEN_abcdefghij')));
      // 帖子列表相反，必须带 stoken 才是本人视角的帖子。
      final threads = latin1.decode(encode(isThread: true), allowInvalid: true);
      expect(threads, contains('STOKEN_abcdefghij'));
    });

    test('备用形状与 TiebaLite 一致，带 stoken', () {
      final bytes = TiebaProtoCodec.encodeUserPostRequest(
        device: TiebaDevice.ephemeral(),
        uid: 854707021,
        page: 1,
        isThread: false,
        stoken: 'STOKEN_abcdefghij',
        shape: 1,
      );
      expect(
        latin1.decode(bytes, allowInvalid: true),
        contains('STOKEN_abcdefghij'),
      );
    });

    test('两个页签都由 is_thread 字段区分', () {
      int isThreadOf(Uint8List bytes) {
        final outer = ProtoReader(bytes);
        final field = outer.nextField();
        expect(field?.tag, 1);
        final data = outer.readSubReader();
        var value = -1;
        data.forEachField((tag, wireType, reader) {
          if (tag == 4) {
            value = reader.readVarint();
            return true;
          }
          return false;
        });
        return value;
      }

      expect(isThreadOf(encode(isThread: true)), 1);
      expect(isThreadOf(encode(isThread: false)), 0);
    });
  });

  group('「回复」列表形状探测', () {
    test('空结果时换形状重试，命中后锁定该形状', () async {
      final adapter = _ShapeAdapter(emptyCalls: 2);
      final api = _api(adapter);

      final first = await api.userPosts(uid: 1, isThread: false);
      expect(first.length, 1);
      expect(adapter.calls, 3);

      // 翻页沿用命中的形状，只发一次请求。
      adapter
        ..emptyCalls = 0
        ..calls = 0;
      final second = await api.userPosts(uid: 1, page: 2, isThread: false);
      expect(second.length, 1);
      expect(adapter.calls, 1);
    });

    test('确实没有回复时不会无限重试', () async {
      final adapter = _ShapeAdapter(emptyCalls: 99);
      final api = _api(adapter);

      expect(await api.userPosts(uid: 1, isThread: false), isEmpty);
      expect(adapter.calls, 3);
    });

    test('帖子列表不参与形状探测', () async {
      final adapter = _ShapeAdapter(emptyCalls: 0);
      final api = _api(adapter);

      await api.userPosts(uid: 1, isThread: true);
      expect(adapter.calls, 1);
    });
  });
}
