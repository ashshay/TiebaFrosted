import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/device.dart';
import 'data/api.dart';
import 'data/cookie_vault.dart';
import 'data/local_db.dart';
import 'data/media_saver.dart';
import 'data/repo.dart';
import 'data/settings.dart';
import 'data/store.dart';

class _PrefsDeviceKv implements DeviceKvStore {
  _PrefsDeviceKv(this._prefs);
  final SharedPreferences _prefs;

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 适度扩大 Flutter 解码图内存缓存上限，减少多图信息流快速上下滚动时的反复解码。
  PaintingBinding.instance.imageCache
    ..maximumSize = 1500
    ..maximumSizeBytes = 160 * 1024 * 1024;
  final prefs = await SharedPreferences.getInstance();
  final settings = FrostedSettings(prefs);
  final device = await TiebaDevice.load(_PrefsDeviceKv(prefs));
  final db = await LocalDb.open();
  final cookies = CookieVault();
  final store = FrostedStore(db: db, prefs: prefs, cookies: cookies);
  await store.init();

  final api = TiebaApi(
    device: device,
    credentialProvider: () => (
      bduss: store.bduss,
      stoken: store.stoken,
      tbs: store.tbs,
      uid: store.uid,
      zid: store.zid,
      webCookie: store.webCookie,
    ),
  );
  final mediaSaver = MediaSaver(api.rawDio);
  final repo = TiebaRepo(
    api: api,
    store: store,
    settings: settings,
    db: db,
    mediaSaver: mediaSaver,
  );
  unawaited(repo.syncDevice());

  runApp(
    TiebaFrostedApp(
      settings: settings,
      store: store,
      db: db,
      mediaSaver: mediaSaver,
      repo: repo,
    ),
  );
}
