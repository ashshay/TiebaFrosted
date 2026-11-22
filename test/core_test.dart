import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:tieba_frosted/core/cuid.dart';
import 'package:tieba_frosted/core/html_text.dart';
import 'package:tieba_frosted/core/links.dart';
import 'package:tieba_frosted/core/proto_wire.dart';
import 'package:tieba_frosted/core/signer.dart';
import 'package:tieba_frosted/ui/widgets/profile_header.dart';

void main() {
  group('Tieba Signer (Kotlin SortAndSignInterceptor parity)', () {
    test('MD5 uppercase matches Kotlin MD5Util.toMd5', () {
      expect(md5Upper('hello'), '5D41402ABC4B2A76B9719D911017C592');
    });

    test('signFormParams sorts by full key=value and appends tiebaclient!!!', () {
      final params = {
        'kz': '123456',
        '_client_version': '12.52.1.0',
        'pn': '1',
        'BDUSS': 'test_bduss',
      };
      final result = signFormParams(params);
      final expectedRaw =
          'BDUSS=test_bduss_client_version=12.52.1.0kz=123456pn=1tiebaclient!!!';
      expect(result.sign, md5Upper(expectedRaw));
      expect(result.sorted.map((e) => e.key).toList(), [
        'BDUSS',
        '_client_version',
        'kz',
        'pn',
      ]);
    });

    test('signMultipartFields sorts by field name', () {
      final res = signMultipartFields({
        'z_id': 'abc',
        '_client_version': '12.52.1.0',
        'stoken': 'xyz',
      });
      expect(
        res.sign,
        md5Upper('_client_version=12.52.1.0stoken=xyzz_id=abctiebaclient!!!'),
      );
    });

    test('Helios CUID / Base32 / Hasher produces deterministic valid format', () {
      const aid = '0123456789abcdef';
      const uuid = '12345678-1234-4123-8123-123456789abc';
      final base = TiebaCuid.baseCuid(aid);
      expect(base.length, 32);
      expect(base, base.toUpperCase());

      final newCuid = TiebaCuid.newCuid(aid);
      expect(newCuid, startsWith('$base|V'));
      expect(newCuid.split('|V').last.length, 8);

      final c3Aid = TiebaCuid.aid(androidId: aid, uuid: uuid);
      expect(c3Aid, startsWith('A00-'));
      final parts = c3Aid.split('-');
      expect(parts.length, 3);
      expect(parts[1].length, 32);
      expect(parts[2].length, 8);
    });

    test('RC442 encrypt/decrypt is symmetric', () {
      final plain = utf8.encode('1234567890abcdef');
      final key = utf8.encode('0123456789abcdef0123456789abcdef');
      final enc = rc442Crypt(plain, key);
      final dec = rc442Crypt(enc, key);
      expect(dec, plain);
    });
  });

  group('ProtoWire encoder/decoder', () {
    test('round-trips scalars, negative int32, double, and nested messages', () {
      final w = ProtoWriter()
        ..writeInt32(1, 42)
        ..writeInt64(2, 9876543210123)
        ..writeString(3, '贴吧测试')
        ..writeBool(4, true)
        ..writeDouble(5, 2.75)
        ..writeInt32(6, -1)
        ..writeSubMessage(7, (sub) {
          sub.writeString(1, 'inner');
          sub.writeInt32(2, 99);
        });

      int f1 = 0;
      int f2 = 0;
      String f3 = '';
      bool f4 = false;
      double f5 = 0;
      int f6 = 0;
      String inner1 = '';
      int inner2 = 0;

      ProtoReader(w.toBytes()).forEachField((tag, wire, r) {
        switch (tag) {
          case 1:
            f1 = r.readInt32();
            return true;
          case 2:
            f2 = r.readInt64();
            return true;
          case 3:
            f3 = r.readString();
            return true;
          case 4:
            f4 = r.readBool();
            return true;
          case 5:
            f5 = r.readDouble();
            return true;
          case 6:
            f6 = r.readInt32();
            return true;
          case 7:
            r.readSubReader().forEachField((st, sw, sr) {
              if (st == 1) {
                inner1 = sr.readString();
                return true;
              }
              if (st == 2) {
                inner2 = sr.readInt32();
                return true;
              }
              return false;
            });
            return true;
          default:
            return false;
        }
      });

      expect(f1, 42);
      expect(f2, 9876543210123);
      expect(f3, '贴吧测试');
      expect(f4, isTrue);
      expect(f5, closeTo(2.75, 1e-9));
      expect(f6, -1);
      expect(inner1, 'inner');
      expect(inner2, 99);
    });
  });

  group('Tieba links & rich text parser', () {
    test('parses thread, forum, user, and web links', () {
      final t = parseTiebaLink('https://tieba.baidu.com/p/88990011?pid=123&cid=456');
      expect(t, isA<TiebaThreadLink>());
      final tl = t as TiebaThreadLink;
      expect(tl.threadId, 88990011);
      expect(tl.postId, 123);
      expect(tl.subPostId, 456);

      final f = parseTiebaLink('https://tieba.baidu.com/f?kw=flutter');
      expect((f as TiebaForumLink).forumName, 'flutter');

      final u = parseTiebaLink('https://tieba.baidu.com/home/main?id=tb.1.abc');
      expect((u as TiebaUserLink).portrait, 'tb.1.abc');
    });

    test('parses emoticons and urls in plain text', () {
      final nodes = parseTiebaPlainText('你好#(滑稽)看看 https://tieba.baidu.com/p/123');
      expect(nodes.length, 4);
      expect((nodes[0] as RichTextNode).text, '你好');
      expect((nodes[1] as RichEmoticonNode).id, 'image_emoticon25');
      expect((nodes[2] as RichTextNode).text, '看看 ');
      expect((nodes[3] as RichLinkNode).url, 'https://tieba.baidu.com/p/123');
    });

    test('unwraps the checkurl redirect to the real target', () {
      final link = parseTiebaLink(
        'https://tieba.baidu.com/mo/q/checkurl?url=https%3A%2F%2Fexample.com%2Fa',
      );
      expect((link as TiebaWebLink).url, 'https://example.com/a');
    });

    test('repairs the doubled scheme checkurl sometimes carries', () {
      final link = parseTiebaLink(
        'https://tieba.baidu.com/mo/q/checkurl?url=http%3A%2F%2Fhttps%3A%2F%2Fexample.com',
      );
      expect((link as TiebaWebLink).url, 'https://example.com');
    });

    test('checkurl pointing at a thread opens the thread', () {
      final link = parseTiebaLink(
        'https://tieba.baidu.com/mo/q/checkurl?url=https%3A%2F%2Ftieba.baidu.com%2Fp%2F777',
      );
      expect((link as TiebaThreadLink).threadId, 777);
    });

    test('tiebaclient preview_file unwraps to its url', () {
      final link = parseTiebaLink(
        'tiebaclient://action/preview_file?url=https%3A%2F%2Fexample.com%2Fimg.png',
      );
      expect((link as TiebaWebLink).url, 'https://example.com/img.png');
    });

    test('other tiebaclient actions fall back to a web link', () {
      final link = parseTiebaLink('tiebaclient://action/unknown');
      expect(link, isA<TiebaWebLink>());
    });
  });

  group('ProfileHeaderLayout geometry regression', () {
    test('elements never clip outside header extent across progress 0..1', () {
      for (final topInset in const [0.0, 24.0, 44.0]) {
        for (final textScale in const [0.85, 1.0, 1.3]) {
          final nameLine = 22.0 * textScale * 1.3;
          for (var step = 0; step <= 100; step++) {
            final p = step / 100.0;
            final layout = ProfileHeaderLayout.at(
              progress: p,
              topInset: topInset,
              nameLine: nameLine,
              textScale: textScale,
              showBack: true,
              onSurface: const Color(0xFFFFFFFF),
            );
            expect(layout.extent, greaterThanOrEqualTo(topInset + 56.0 - 1e-6));
            expect(
              layout.nameTop + layout.nameHeight,
              lessThanOrEqualTo(layout.extent + 1e-6),
              reason: 'name clips at p=$p top=$topInset scale=$textScale',
            );
            expect(
              layout.avatarTop + layout.avatarSize,
              lessThanOrEqualTo(layout.extent + 1e-6),
              reason: 'avatar clips at p=$p top=$topInset scale=$textScale',
            );
          }
        }
      }
    });
  });
}
