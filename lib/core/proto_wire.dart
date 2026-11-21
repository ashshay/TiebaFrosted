import 'dart:convert';
import 'dart:typed_data';

/// 纯 Dart Protobuf Wire Format 编解码器（零 codegen、容错跳过未知字段）。
///
/// 贴吧服务端使用标准 proto3 线格式；手写 Wire 编解码可以：
/// 1. 直接解析所有 20+ 个 Protobuf 接口而无需生成 300+ 个笨重类；
/// 2. 自动容忍未知字段、非标准 UTF-8 与类型漂移。
abstract final class WireType {
  static const int varint = 0;
  static const int fixed64 = 1;
  static const int lengthDelimited = 2;
  static const int startGroup = 3;
  static const int endGroup = 4;
  static const int fixed32 = 5;
}

class ProtoWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List toBytes() => _builder.toBytes();

  void _writeTag(int fieldNumber, int wireType) {
    _writeVarint((fieldNumber << 3) | wireType);
  }

  void _writeVarint(int value) {
    var v = value;
    // Dart int 是 64 位有符号；负数的 varint 按 64 位二进制补码无符号右移 7 位输出 10 字节。
    while (true) {
      if ((v & ~0x7F) == 0) {
        _builder.addByte(v & 0x7F);
        return;
      }
      _builder.addByte((v & 0x7F) | 0x80);
      v = v >>> 7;
    }
  }

  void writeInt32(int fieldNumber, int? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value);
  }

  void writeInt64(int fieldNumber, int? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value);
  }

  void writeUint32(int fieldNumber, int? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value & 0xFFFFFFFF);
  }

  void writeUint64(int fieldNumber, int? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value);
  }

  void writeBool(int fieldNumber, bool? value, {bool emitFalse = false}) {
    if (value == null) return;
    if (!emitFalse && !value) return;
    _writeTag(fieldNumber, WireType.varint);
    _writeVarint(value ? 1 : 0);
  }

  void writeDouble(int fieldNumber, double? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0.0) return;
    _writeTag(fieldNumber, WireType.fixed64);
    final bd = ByteData(8)..setFloat64(0, value, Endian.little);
    _builder.add(bd.buffer.asUint8List());
  }

  void writeFloat(int fieldNumber, double? value, {bool emitZero = false}) {
    if (value == null) return;
    if (!emitZero && value == 0.0) return;
    _writeTag(fieldNumber, WireType.fixed32);
    final bd = ByteData(4)..setFloat32(0, value, Endian.little);
    _builder.add(bd.buffer.asUint8List());
  }

  void writeString(int fieldNumber, String? value, {bool emitEmpty = false}) {
    if (value == null) return;
    if (!emitEmpty && value.isEmpty) return;
    final bytes = utf8.encode(value);
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(bytes.length);
    _builder.add(bytes);
  }

  void writeBytes(int fieldNumber, List<int>? value, {bool emitEmpty = false}) {
    if (value == null) return;
    if (!emitEmpty && value.isEmpty) return;
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(value.length);
    _builder.add(value);
  }

  void writeMessage(int fieldNumber, Uint8List? messageBytes, {bool emitEmpty = false}) {
    if (messageBytes == null) return;
    if (!emitEmpty && messageBytes.isEmpty) return;
    _writeTag(fieldNumber, WireType.lengthDelimited);
    _writeVarint(messageBytes.length);
    _builder.add(messageBytes);
  }

  void writeSubMessage(int fieldNumber, void Function(ProtoWriter w) encode) {
    final nested = ProtoWriter();
    encode(nested);
    writeMessage(fieldNumber, nested.toBytes(), emitEmpty: true);
  }
}

class ProtoField {
  const ProtoField(this.tag, this.wireType);

  final int tag;
  final int wireType;
}

class ProtoReader {
  ProtoReader(this._bytes, [this._pos = 0, int? end])
      : _end = end ?? _bytes.length;

  final Uint8List _bytes;
  int _pos;
  final int _end;

  bool get isAtEnd => _pos >= _end;

  /// 读取下一个字段头；到达末尾或数据截断时返回 null。
  ProtoField? nextField() {
    if (_pos >= _end) return null;
    final key = readVarint();
    if (key == 0) {
      _pos = _end;
      return null;
    }
    return ProtoField(key >>> 3, key & 0x07);
  }

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (_pos < _end && shift < 64) {
      final b = _bytes[_pos++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return result;
      shift += 7;
    }
    return result;
  }

  int readInt32() => readVarint().toSigned(32);

  int readUint32() => readVarint() & 0xFFFFFFFF;

  int readInt64() => readVarint();

  bool readBool() => readVarint() != 0;

  double readDouble() {
    if (_pos + 8 > _end) {
      _pos = _end;
      return 0.0;
    }
    final bd = ByteData.sublistView(_bytes, _pos, _pos + 8);
    _pos += 8;
    return bd.getFloat64(0, Endian.little);
  }

  double readFloat() {
    if (_pos + 4 > _end) {
      _pos = _end;
      return 0.0;
    }
    final bd = ByteData.sublistView(_bytes, _pos, _pos + 4);
    _pos += 4;
    return bd.getFloat32(0, Endian.little);
  }

  int readFixed64() {
    if (_pos + 8 > _end) {
      _pos = _end;
      return 0;
    }
    final bd = ByteData.sublistView(_bytes, _pos, _pos + 8);
    _pos += 8;
    return bd.getInt64(0, Endian.little);
  }

  int readFixed32() {
    if (_pos + 4 > _end) {
      _pos = _end;
      return 0;
    }
    final bd = ByteData.sublistView(_bytes, _pos, _pos + 4);
    _pos += 4;
    return bd.getUint32(0, Endian.little);
  }

  Uint8List readBytes() {
    final len = readVarint();
    if (len <= 0 || _pos >= _end) return Uint8List(0);
    final actualEnd = (_pos + len).clamp(_pos, _end);
    final slice = Uint8List.sublistView(_bytes, _pos, actualEnd);
    _pos = actualEnd;
    return slice;
  }

  String readString() {
    final slice = readBytes();
    if (slice.isEmpty) return '';
    return utf8.decode(slice, allowMalformed: true);
  }

  ProtoReader readSubReader() {
    final len = readVarint();
    if (len <= 0 || _pos >= _end) return ProtoReader(_bytes, _end, _end);
    final start = _pos;
    final actualEnd = (_pos + len).clamp(_pos, _end);
    _pos = actualEnd;
    return ProtoReader(_bytes, start, actualEnd);
  }

  /// 读取可能为 packed（length-delimited）或单值的 varint 列表。
  void readPackedVarints(int wireType, List<int> out) {
    if (wireType == WireType.varint) {
      out.add(readVarint());
    } else if (wireType == WireType.lengthDelimited) {
      final sub = readSubReader();
      while (!sub.isAtEnd) {
        out.add(sub.readVarint());
      }
    } else {
      skip(wireType);
    }
  }

  void skip(int wireType) {
    switch (wireType) {
      case WireType.varint:
        readVarint();
      case WireType.fixed64:
        _pos = (_pos + 8).clamp(_pos, _end);
      case WireType.lengthDelimited:
        final len = readVarint();
        if (len > 0) _pos = (_pos + len).clamp(_pos, _end);
      case WireType.fixed32:
        _pos = (_pos + 4).clamp(_pos, _end);
      case WireType.startGroup:
        while (!isAtEnd) {
          final f = nextField();
          if (f == null || f.wireType == WireType.endGroup) break;
          skip(f.wireType);
        }
      case WireType.endGroup:
        break;
      default:
        _pos = _end;
    }
  }

  /// 便捷遍历器：自动对未处理字段调用 `skip`。
  void forEachField(bool Function(int tag, int wireType, ProtoReader r) handler) {
    while (!isAtEnd) {
      final f = nextField();
      if (f == null) break;
      final consumed = handler(f.tag, f.wireType, this);
      if (!consumed) skip(f.wireType);
    }
  }
}
