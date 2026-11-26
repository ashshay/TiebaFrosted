import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tieba_frosted/core/device.dart';
import 'package:tieba_frosted/data/api.dart';
import 'package:tieba_frosted/data/cookie_vault.dart';
import 'package:tieba_frosted/data/local_db.dart';
import 'package:tieba_frosted/data/media_saver.dart';
import 'package:tieba_frosted/data/models.dart';
import 'package:tieba_frosted/data/repo.dart';
import 'package:tieba_frosted/data/settings.dart';
import 'package:tieba_frosted/data/store.dart';

/// 一个只会回「用户未登录」的适配器，用来验证写操作的自愈分支不依赖真实网络。
class _LoginFailureAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"error_code":1,"error_msg":"用户未登录或登录失败，请更换账号或重试"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 记录请求体并一律回成功的适配器。
class _RecorderAdapter implements HttpClientAdapter {
  final List<String> bodies = [];
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final chunks = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        chunks.addAll(chunk);
      }
    }
    bodies.add(String.fromCharCodes(chunks));
    return ResponseBody.fromString(
      '{"error_code":"0","error_msg":""}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 模拟原生 Cookie 通道：贴吧域名下同时有一份「好」的 STOKEN。
void _mockTiebaCookies({String bduss = 'BDUSS_TEST', String stoken = ''}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('frosted/cookies'),
    (call) async {
      if (call.method == 'readRaw') {
        final parts = <String>[
          if (bduss.isNotEmpty) 'BDUSS=$bduss',
          if (stoken.isNotEmpty) 'STOKEN=$stoken',
          'BAIDUZID=ZID_FROM_JAR',
          'BAIDUID=BAIDUID_FROM_JAR',
        ];
        return parts.join('; ');
      }
      if (call.method == 'read') {
        return <String, String>{
          if (bduss.isNotEmpty) 'BDUSS': bduss,
          if (stoken.isNotEmpty) 'STOKEN': stoken,
        };
      }
      return null;
    },
  );
}

Future<({TiebaRepo repo, FrostedStore store, _LoginFailureAdapter adapter})>
_setup({String stoken = '', String tbs = '', String bduss = 'BDUSS_TEST'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = FrostedSettings(prefs);
  final db = LocalDb.inMemory();
  final cookies = CookieVault();
  final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
  await store.init();
  final adapter = _LoginFailureAdapter();
  final dio = Dio()..httpClientAdapter = adapter;
  final api = TiebaApi(
    device: TiebaDevice.ephemeral(),
    dio: dio,
    credentialProvider: () => (
      bduss: store.bduss,
      stoken: store.stoken,
      tbs: store.tbs,
      uid: store.uid,
      zid: store.zid,
      webCookie: '',
    ),
  );
  final repo = TiebaRepo(
    api: api,
    store: store,
    settings: settings,
    db: db,
    mediaSaver: MediaSaver(api.rawDio),
  );
  await store.saveAccount(
    AccountRecord(
      uid: '1001',
      name: 'alice',
      bduss: bduss,
      stoken: stoken,
      tbs: tbs,
    ),
  );
  return (repo: repo, store: store, adapter: adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('frosted/cookies'), null);
  });

  group('写操作凭据判定', () {
    test('只有 BDUSS 的账号被判成只读，并指出缺哪一块', () {
      const readOnly = AccountRecord(uid: '1', name: 'a', bduss: 'B');
      expect(readOnly.canWrite, isFalse);
      expect(readOnly.writeBlockReason, 'STOKEN / tbs');

      const full = AccountRecord(
        uid: '1',
        name: 'a',
        bduss: 'B',
        stoken: 'S',
        tbs: 'T',
      );
      expect(full.canWrite, isTrue);
      expect(full.writeBlockReason, isEmpty);
    });

    test('store 把当前账号的可写状态透出去', () async {
      final env = await _setup(stoken: 'S', tbs: 'T');
      expect(env.store.canWrite, isTrue);
      expect(env.store.writeBlockReason, isEmpty);
    });
  });

  group('ensureWritableSession', () {
    test('凭据齐全时不做额外网络请求', () async {
      final env = await _setup(stoken: 'S', tbs: 'T');
      await env.repo.ensureWritableSession();
      expect(env.adapter.calls, 0);
    });

    test('缺 tbs 时向 /c/s/login 补一次，失败仍给出可照做的错误', () async {
      final env = await _setup(bduss: 'BDUSS_TEST');
      await expectLater(
        env.repo.ensureWritableSession(),
        throwsA(
          isA<TiebaApiException>()
              .having((e) => e.isLoginFailure, 'isLoginFailure', isFalse)
              .having((e) => e.message, 'message', contains('STOKEN')),
        ),
      );
      // 补 tbs 的那次 /c/s/login 请求确实发出去了
      expect(env.adapter.calls, 1);
    });

    test('未登录时先提示登录', () async {
      final env = await _setup(bduss: '');
      await expectLater(
        env.repo.ensureWritableSession(),
        throwsA(
          isA<TiebaApiException>()
              .having((e) => e.message, 'message', contains('请先登录')),
        ),
      );
    });
  });

  group('贴吧域名的 STOKEN 优先', () {
    test('账号里的 STOKEN 抓错时按贴吧域名 Cookie 纠正', () async {
      _mockTiebaCookies(bduss: 'BDUSS_TEST', stoken: 'GOOD_STOKEN');
      final env = await _setup(bduss: 'BDUSS_TEST', stoken: 'WRONG_STOKEN', tbs: 'T');

      await env.repo.ensureWritableSession();

      expect(env.store.stoken, 'GOOD_STOKEN');
      expect(env.store.zid, 'ZID_FROM_JAR');
    });

    test('Cookie 罐属于别的账号时不覆盖当前账号凭据', () async {
      _mockTiebaCookies(bduss: 'OTHER_BDUSS', stoken: 'OTHER_STOKEN');
      final env = await _setup(bduss: 'BDUSS_TEST', stoken: 'MY_STOKEN', tbs: 'T');

      await env.repo.ensureWritableSession();

      expect(env.store.stoken, 'MY_STOKEN');
    });
  });

  group('收藏请求', () {
    test('带上 tbs 与 user_id，STOKEN 失效时仍有 tbs 可认证', () async {
      final recorder = _RecorderAdapter();
      final api = TiebaApi(
        device: TiebaDevice.ephemeral(),
        dio: Dio()..httpClientAdapter = recorder,
        credentialProvider: () => (
          bduss: 'BDUSS_TEST',
          stoken: 'STOKEN_TEST',
          tbs: 'TBS_TEST',
          uid: '1001',
          zid: 'ZID_TEST',
          webCookie: '',
        ),
      );

      await api.addThreadStore(threadId: 1, postId: 2);

      final form = Uri.splitQueryString(recorder.bodies.single);
      expect(form['stoken'], 'STOKEN_TEST');
      expect(form['tbs'], 'TBS_TEST');
      expect(form['user_id'], '1001');
      expect(form['BDUSS'], 'BDUSS_TEST');
      expect(form['data'], contains('"tid":"1"'));
      expect(form['sign'], isNotEmpty);
    });
  });

  group('登录失败识别', () {
    test('error_code=1 + 未登录提示才当成登录态问题', () {
      expect(
        const TiebaApiException(1, '用户未登录或登录失败，请更换账号或重试').isLoginFailure,
        isTrue,
      );
      expect(const TiebaApiException(1, '操作太频繁').isLoginFailure, isFalse);
      expect(const TiebaApiException(340006, '用户未登录').isLoginFailure, isFalse);
    });
  });

  group('CookieVault 补齐', () {
    test('fillMissing 只补缺失的键，不覆盖已有值', () {
      final vault = CookieVault()..loadFromRaw('BDUSS=keep; STOKEN=old');
      vault.fillMissing({
        'BDUSS': 'new',
        'STOKEN': 'new',
        'BAIDUZID': 'zid-value',
        'BAIDUID': 'baiduid-value',
        '': 'ignored',
      });
      expect(vault.bduss, 'keep');
      expect(vault.stoken, 'old');
      expect(vault.zid, 'zid-value');
      expect(vault.baiduId, 'baiduid-value');
    });
  });
}
