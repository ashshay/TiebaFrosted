import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 贴吧客户端默认签名密钥（与 TiebaLite SortAndSignInterceptor 一致）。
const tiebaAppSecret = 'tiebaclient!!!';

/// 计算 UTF-8 字符串的 32 位大写十六进制 MD5（与 TiebaLite MD5Util.toMd5 一致）。
String md5Upper(String input) =>
    md5.convert(utf8.encode(input)).toString().toUpperCase();

/// 计算 UTF-8 字符串的 32 位小写十六进制 MD5（Sofire / 资源 ID 使用）。
String md5Lower(String input) =>
    md5.convert(utf8.encode(input)).toString().toLowerCase();

/// 计算原始字节的 16 字节 MD5 摘要。
Uint8List md5Bytes(List<int> input) =>
    Uint8List.fromList(md5.convert(input).bytes);

/// 核心签名函数：`MD5(sortedRaw + appSecret)`（大写 32 位十六进制）。
String calculateTiebaSign(
  String sortedRaw, {
  String appSecret = tiebaAppSecret,
}) => md5Upper('$sortedRaw$appSecret');

/// 对表单或 Multipart 文本字段排序并生成签名。
///
/// 与 `SortAndSignInterceptor` 严格对齐：
/// - FormBody：`decoded "$k=$v"` 整串字典序排序后无分隔符拼接 + secret 求 MD5；
/// - Multipart：按字段 `name` 排序后拼接 `"$k=$v"` + secret 求 MD5。
({List<MapEntry<String, String>> sorted, String sign}) signFormParams(
  Map<String, String> params, {
  String appSecret = tiebaAppSecret,
}) {
  final pairs = [
    for (final e in params.entries) '${e.key}=${e.value}',
  ]..sort();
  final sign = calculateTiebaSign(pairs.join(), appSecret: appSecret);
  final sortedEntries = params.entries.toList()
    ..sort((a, b) => '${a.key}=${a.value}'.compareTo('${b.key}=${b.value}'));
  return (sorted: sortedEntries, sign: sign);
}

({List<MapEntry<String, String>> sorted, String sign}) signMultipartFields(
  Map<String, String> fields, {
  String appSecret = tiebaAppSecret,
}) {
  final sortedEntries = fields.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final raw = sortedEntries.map((e) => '${e.key}=${e.value}').join();
  final sign = calculateTiebaSign(raw, appSecret: appSecret);
  return (sorted: sortedEntries, sign: sign);
}

/// 生成已排序且附带 `sign` 的 `application/x-www-form-urlencoded` 文本。
///
/// 空格用 `%20` 而不是 `+`：与 OkHttp 的 `FormBody` 逐字节一致，避免服务端
/// 拿原始报文重算签名时因编码差异对不上。
String encodeSignedFormBody(
  Map<String, String> params, {
  String appSecret = tiebaAppSecret,
}) {
  final res = signFormParams(params, appSecret: appSecret);
  final encodedPairs = [
    for (final e in res.sorted)
      '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
  ]..sort();
  encodedPairs.add('sign=${res.sign}');
  return encodedPairs.join('&');
}

/// 标准 IEEE 802.3 CRC32（无符号 32 位）。
int crc32(List<int> bytes, [int offset = 0, int? length]) {
  final end = length == null ? bytes.length : offset + length;
  var crc = 0xFFFFFFFF;
  for (var i = offset; i < end; i++) {
    crc = _crcTable[(crc ^ (bytes[i] & 0xFF)) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var c = i;
    for (var j = 0; j < 8; j++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c & 0xFFFFFFFF;
  }
  return table;
}();

int _u32(int v) => v & 0xFFFFFFFF;

int _rotl32(int v, int shift) {
  final x = _u32(v);
  return _u32((x << shift) | (x >>> (32 - shift)));
}

int _mul32(int a, int b) {
  // Dart VM int 为 64 位有符号，拆分 16 位避免中间溢出。
  final ua = _u32(a);
  final ub = _u32(b);
  final aLo = ua & 0xFFFF;
  final aHi = ua >>> 16;
  final bLo = ub & 0xFFFF;
  final bHi = ub >>> 16;
  return _u32((aLo * bLo) + (((aHi * bLo + aLo * bHi) & 0xFFFF) << 16));
}

int _readU32Le(List<int> data, int offset) =>
    (data[offset] & 0xFF) |
    ((data[offset + 1] & 0xFF) << 8) |
    ((data[offset + 2] & 0xFF) << 16) |
    ((data[offset + 3] & 0xFF) << 24);

/// 与 TiebaLite `utils/helios/XXHash.java` 逐位一致的 XXHash32 实现。
int xxHash32(List<int> data, {int offset = 0, int? length, int seed = 0}) {
  const prime1 = 0x9E3779B1; // -1640531535
  const prime2 = 0x85EBCA77; // -2048144777
  const prime3 = 0xC2B2AE3D; // -1028477379
  const prime4 = 0x27D4EB2F; // 668265263
  const prime5 = 0x165667B1; // 374761393

  final len = length ?? (data.length - offset);
  var v1 = _u32(seed + prime1 + prime2);
  var v2 = _u32(seed + prime2);
  var v3 = _u32(seed);
  var v4 = _u32(seed - prime1);

  var p = offset;
  final end = offset + len;

  if (len >= 16) {
    final limit = end - 16;
    while (p <= limit) {
      v1 = _mul32(_rotl32(_u32(v1 + _mul32(_readU32Le(data, p), prime2)), 13), prime1);
      v2 = _mul32(_rotl32(_u32(v2 + _mul32(_readU32Le(data, p + 4), prime2)), 13), prime1);
      v3 = _mul32(_rotl32(_u32(v3 + _mul32(_readU32Le(data, p + 8), prime2)), 13), prime1);
      v4 = _mul32(_rotl32(_u32(v4 + _mul32(_readU32Le(data, p + 12), prime2)), 13), prime1);
      p += 16;
    }
  }

  // 与 XXHash.java:94 保持一致：严格 `len > 16`。
  var h32 = len > 16
      ? _u32(_rotl32(v1, 1) + _rotl32(v2, 7) + _rotl32(v3, 12) + _rotl32(v4, 18))
      : _u32(v3 + prime5);
  h32 = _u32(h32 + len);

  while (p <= end - 4) {
    h32 = _mul32(_rotl32(_u32(h32 + _mul32(_readU32Le(data, p), prime3)), 17), prime4);
    p += 4;
  }
  while (p < end) {
    h32 = _mul32(_rotl32(_u32(h32 + _mul32(data[p] & 0xFF, prime5)), 11), prime1);
    p++;
  }

  h32 = _mul32(h32 ^ (h32 >>> 15), prime2);
  h32 = _mul32(h32 ^ (h32 >>> 13), prime3);
  return _u32(h32 ^ (h32 >>> 16));
}

/// 与 TiebaLite `utils/helios/Hasher.java` 逐位一致的 40-bit 摘要（返回 5 字节小端）。
Uint8List heliosHash(List<int> bytes) {
  const encoders = [
    (isCrc: true, start: 8, flag: 0),
    (isCrc: false, start: 0, flag: 1),
    (isCrc: false, start: 1, flag: 1),
    (isCrc: true, start: 7, flag: 1),
  ];
  var bits = 0xFFFFFFFFFF; // 40 bits all 1
  final buf = Uint8List(bytes.length + (encoders.length + 1) * 5);
  buf.setRange(0, bytes.length, bytes);

  void writeResult(int offset) {
    for (var j = 0; j < 5; j++) {
      buf[offset + j] = (bits >>> (j * 8)) & 0xFF;
    }
  }

  writeResult(bytes.length);
  for (var i = 0; i < encoders.length; i++) {
    final enc = encoders[i];
    final len = bytes.length + (i + 1) * 5;
    final val = enc.isCrc ? crc32(buf, 0, len) : xxHash32(buf, length: len);
    var slice = (bits >>> enc.start) & 0xFFFFFFFF;
    if (enc.flag == 0) {
      slice &= val;
    } else {
      slice ^= val;
    }
    final mask = 0xFFFFFFFF << enc.start;
    bits = ((bits & ~mask) | (slice << enc.start)) & 0xFFFFFFFFFF;
    writeResult(len);
  }

  final out = Uint8List(5);
  for (var j = 0; j < 5; j++) {
    out[j] = (bits >>> (j * 8)) & 0xFF;
  }
  return out;
}

/// 无填充 Base32 编码（与 TiebaLite `utils/helios/Base32.kt` 完全一致）。
String heliosBase32Encode(List<int> bytes) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=';
  final sb = StringBuffer();
  final blocks = (bytes.length + 4) ~/ 5;
  for (var i = 0; i < blocks; i++) {
    final s = List<int>.filled(5, 0);
    var valid = 5;
    for (var k = 0; k < 5; k++) {
      final idx = i * 5 + k;
      if (idx < bytes.length) {
        s[k] = bytes[idx] & 0xFF;
      } else {
        s[k] = 0;
        valid--;
      }
    }
    final dt = switch (valid) {
      1 => 6,
      2 => 4,
      3 => 3,
      4 => 1,
      5 => 0,
      _ => -1,
    };
    final out = [
      (s[0] >>> 3) & 31,
      ((s[0] & 7) << 2) | ((s[1] >>> 6) & 3),
      (s[1] >>> 1) & 31,
      ((s[1] & 1) << 4) | ((s[2] >>> 4) & 15),
      ((s[2] & 15) << 1) | ((s[3] >>> 7) & 1),
      (s[3] >>> 2) & 31,
      ((s[3] & 3) << 3) | ((s[4] >>> 5) & 7),
      s[4] & 31,
    ];
    for (var k = 0; k < out.length - dt; k++) {
      sb.write(alphabet[out[k]]);
    }
  }
  return sb.toString();
}

/// RC4-42 流密码（Sofire `z_id` 获取用，输出额外异或 42）。
Uint8List rc442Crypt(List<int> src, List<int> key) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + (key[i % key.length] & 0xFF)) & 0xFF;
    final tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
  }
  final out = Uint8List(src.length);
  var i = 0;
  j = 0;
  for (var k = 0; k < src.length; k++) {
    i = (i + 1) & 0xFF;
    j = (j + s[i]) & 0xFF;
    final tmp = s[i];
    s[i] = s[j];
    s[j] = tmp;
    final keystream = s[(s[i] + s[j]) & 0xFF];
    out[k] = ((src[k] & 0xFF) ^ keystream) ^ 42;
  }
  return out;
}
