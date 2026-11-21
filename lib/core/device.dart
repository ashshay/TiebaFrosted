import 'dart:convert';
import 'dart:math';

import 'cuid.dart';

/// 贴吧客户端版本号常量（与 TiebaLite ClientVersion 枚举一致）。
abstract final class TiebaClientVersion {
  static const v11 = '11.10.8.6';
  static const v12 = '12.52.1.0';
  static const v12Post = '12.52.1.0';
  static const v22 = '22.10.1.0';
  static const mini = '7.2.0.0';
  static const miniAlt = '8.0.8.0';
  static const legacyNew = '8.2.2';
}

/// 可插拔键值存储接口，使 `core/device.dart` 保持纯 Dart（无 Flutter 依赖）。
abstract interface class DeviceKvStore {
  String? getString(String key);
  int? getInt(String key);
  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
}

/// 贴吧设备指纹与运行时状态（避免每次冷启动随机重置触发风控）。
class TiebaDevice {
  TiebaDevice({
    required this.uuid,
    required this.androidId,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.activeTimestamp,
    this.clientId,
    this.sampleId = '',
    this.baiduId = '',
    this.model = 'Pixel 8',
    this.brand = 'Google',
    this.osVersion = '34',
    this.screenWidth = 1080,
    this.screenHeight = 2400,
    this.screenDensity = 2.75,
    DeviceKvStore? kv,
  }) : _kv = kv,
       initTimeMs = DateTime.now().millisecondsSinceEpoch,
       randomClientId =
           'wappc_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';

  final DeviceKvStore? _kv;
  final String uuid;
  final String androidId;
  final int firstInstallTime;
  final int lastUpdateTime;
  int activeTimestamp;
  String? clientId;
  String sampleId;
  String baiduId;

  final String model;
  final String brand;
  final String osVersion;
  int screenWidth;
  int screenHeight;
  double screenDensity;

  final int initTimeMs;
  final String randomClientId;

  String get effectiveClientId =>
      (clientId != null && clientId!.isNotEmpty) ? clientId! : randomClientId;

  String get baseCuid => TiebaCuid.baseCuid(androidId);
  String get finalCuid => TiebaCuid.finalCuid(androidId);
  String get newCuid => TiebaCuid.newCuid(androidId);
  String get aid => TiebaCuid.aid(androidId: androidId, uuid: uuid);

  String get imei => TiebaCuid.defaultImei;

  String get base64AndroidId => base64Encode(utf8.encode(androidId));

  String get oaidJson => '{"v":"","sc":-200,"sup":0,"isTrackLimited":0}';

  String get deviceScore => '0.423';

  static const defaultWebUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/135.0.0.0 Mobile Safari/537.36';

  String userAgent([String? append]) {
    if (append == null || append.trim().isEmpty) return defaultWebUserAgent;
    return '$defaultWebUserAgent ${append.trim()}';
  }

  String get eventDay {
    final now = DateTime.now();
    final dd = now.day < 10 ? '0${now.day}' : '${now.day}';
    return '${now.year}${now.month}$dd';
  }

  static Future<TiebaDevice> load(DeviceKvStore kv) async {
    final rand = Random.secure();
    var uuid = kv.getString('tb_device_uuid');
    if (uuid == null || uuid.isEmpty) {
      uuid = _generateUuidV4(rand);
      await kv.setString('tb_device_uuid', uuid);
    }
    var androidId = kv.getString('tb_device_android_id');
    if (androidId == null || androidId.isEmpty) {
      androidId = List.generate(
        16,
        (_) => rand.nextInt(16).toRadixString(16),
      ).join();
      await kv.setString('tb_device_android_id', androidId);
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var firstInstall = kv.getInt('tb_first_install_time');
    if (firstInstall == null || firstInstall <= 0) {
      firstInstall = nowMs;
      await kv.setInt('tb_first_install_time', firstInstall);
    }
    final lastUpdate = kv.getInt('tb_last_update_time') ?? firstInstall;
    final activeTs = kv.getInt('tb_active_timestamp') ?? nowMs;
    return TiebaDevice(
      uuid: uuid,
      androidId: androidId,
      firstInstallTime: firstInstall,
      lastUpdateTime: lastUpdate,
      activeTimestamp: activeTs,
      clientId: kv.getString('tb_client_id'),
      sampleId: kv.getString('tb_sample_id') ?? '',
      baiduId: kv.getString('tb_baidu_id') ?? '',
      kv: kv,
    );
  }

  /// 纯内存测试 / 无持久化环境构造器。
  factory TiebaDevice.ephemeral() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return TiebaDevice(
      uuid: '12345678-1234-4123-8123-123456789abc',
      androidId: '0123456789abcdef',
      firstInstallTime: nowMs,
      lastUpdateTime: nowMs,
      activeTimestamp: nowMs,
    );
  }

  Future<void> updateSync({
    String? newClientId,
    String? newSampleId,
  }) async {
    var changed = false;
    if (newClientId != null && newClientId.isNotEmpty) {
      clientId = newClientId;
      await _kv?.setString('tb_client_id', newClientId);
      changed = true;
    }
    if (newSampleId != null && newSampleId.isNotEmpty) {
      sampleId = newSampleId;
      await _kv?.setString('tb_sample_id', newSampleId);
      changed = true;
    }
    if (changed) {
      activeTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _kv?.setInt('tb_active_timestamp', activeTimestamp);
    }
  }

  Future<void> updateBaiduId(String value) async {
    final clean = value.trim();
    if (clean.isEmpty || clean == baiduId) return;
    baiduId = clean;
    await _kv?.setString('tb_baidu_id', clean);
  }

  void updateScreen({
    required int width,
    required int height,
    required double density,
  }) {
    if (width > 0) screenWidth = width;
    if (height > 0) screenHeight = height;
    if (density > 0) screenDensity = density;
  }

  static String _generateUuidV4(Random rand) {
    final b = List<int>.generate(16, (_) => rand.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String hex(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
        '${hex(4)}${hex(5)}-'
        '${hex(6)}${hex(7)}-'
        '${hex(8)}${hex(9)}-'
        '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
  }
}
