import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/core/proto_wire.dart';
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

void main() {
  group('用户帖子 / 回复列表请求', () {
    test('「回复」列表不带 stoken：服务端见到 stoken 会回落到视频页签返回空', () {
      final replies = latin1.decode(encode(isThread: false), allowInvalid: true);
      expect(replies, isNot(contains('STOKEN_abcdefghij')));
      // 帖子列表相反，必须带 stoken 才是本人视角的帖子。
      final threads = latin1.decode(encode(isThread: true), allowInvalid: true);
      expect(threads, contains('STOKEN_abcdefghij'));
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
}
