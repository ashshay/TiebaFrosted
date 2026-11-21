import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'signer.dart';

/// 贴吧 CUID / Galaxy2 / Galaxy3 (c3_aid) 生成工具（与 TiebaLite UIDUtil / CuidUtils 一致）。
abstract final class TiebaCuid {
  static const defaultImei = '000000000000000';

  /// Android 6+ 基础 CUID：`MD5("com.baidu" + androidId).toUpperCase()`。
  static String baseCuid(String androidId) =>
      md5Upper('com.baidu$androidId');

  /// 旧版 / Mini / New 接口使用的 `finalCUID`：`$baseCuid|${imei.reversed}`。
  static String finalCuid(String androidId, {String imei = defaultImei}) {
    final effectiveImei = imei.isEmpty ? '0' : imei;
    final reversed = effectiveImei.split('').reversed.join();
    return '${baseCuid(androidId)}|$reversed';
  }

  /// 新版 Official / Protobuf / Web 接口使用的 `cuid_galaxy2`：`$baseCuid|V$heliosBase32`。
  static String newCuid(String androidId) {
    final cuid = baseCuid(androidId);
    final encoded = heliosBase32Encode(heliosHash(utf8.encode(cuid)));
    return '$cuid|V$encoded';
  }

  /// `c3_aid` (`cuid_galaxy3`)：`A00-${base32(sha1("com.helios" + androidId + uuid))}-${base32(heliosHash)}`。
  static String aid({required String androidId, required String uuid}) {
    final effectiveAndroidId = androidId.isEmpty ? '000000000' : androidId;
    final sha1Bytes = sha1.convert(
      utf8.encode('com.helios$effectiveAndroidId$uuid'),
    ).bytes;
    final encoded = heliosBase32Encode(sha1Bytes);
    final rawAid = 'A00-$encoded-';
    final sign = heliosBase32Encode(heliosHash(utf8.encode(rawAid)));
    return '$rawAid$sign';
  }

  /// Sofire 请求使用的 CUID。
  static String sofireCuid(String uuid) => '${md5Upper(uuid)}|0';
}
