import 'dart:convert';
import 'dart:typed_data';

/// Minimal MessagePack codec, precise enough to interoperate with the
/// server's `@colyseus/msgpackr` encoder/decoder — but only for the subset
/// of the spec that library actually emits for plain JSON-like values (map,
/// list, string, int, double, bool, null). No bin/ext/timestamp support:
/// this game's messages never need them, and msgpackr never produces them
/// for plain objects either. See `server/schema/messages.ts`'s doc comment
/// for why this exists instead of depending on a Dart msgpack package.
class MsgpackWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  Uint8List encode(Object? value) {
    _write(value);
    return _out.toBytes();
  }

  void _write(Object? value) {
    if (value == null) {
      _out.addByte(0xc0);
    } else if (value is bool) {
      _out.addByte(value ? 0xc3 : 0xc2);
    } else if (value is int) {
      _writeInt(value);
    } else if (value is double) {
      _writeFloat64(value);
    } else if (value is String) {
      _writeString(value);
    } else if (value is List) {
      _writeArrayHeader(value.length);
      for (final item in value) {
        _write(item);
      }
    } else if (value is Map) {
      _writeMapHeader(value.length);
      value.forEach((key, val) {
        _write(key as String);
        _write(val);
      });
    } else {
      throw ArgumentError('Cannot msgpack-encode value of type ${value.runtimeType}');
    }
  }

  void _writeInt(int value) {
    if (value >= 0) {
      if (value < 0x80) {
        _out.addByte(value);
      } else if (value < 0x100) {
        _out.addByte(0xcc);
        _out.addByte(value);
      } else if (value < 0x10000) {
        _out.addByte(0xcd);
        _writeUint16(value);
      } else if (value < 0x100000000) {
        _out.addByte(0xce);
        _writeUint32(value);
      } else {
        _out.addByte(0xcf);
        _writeUint64(value);
      }
    } else {
      if (value >= -0x20) {
        _out.addByte(0xe0 | (value + 0x20));
      } else if (value >= -0x80) {
        _out.addByte(0xd0);
        _out.addByte(value & 0xff);
      } else if (value >= -0x8000) {
        _out.addByte(0xd1);
        _writeUint16(value & 0xffff);
      } else if (value >= -0x80000000) {
        _out.addByte(0xd2);
        _writeUint32(value & 0xffffffff);
      } else {
        _out.addByte(0xd3);
        _writeUint64(value);
      }
    }
  }

  void _writeFloat64(double value) {
    _out.addByte(0xcb);
    final buffer = ByteData(8)..setFloat64(0, value, Endian.big);
    _out.add(buffer.buffer.asUint8List());
  }

  void _writeString(String value) {
    final bytes = utf8.encode(value);
    final length = bytes.length;
    if (length < 0x20) {
      _out.addByte(0xa0 | length);
    } else if (length < 0x100) {
      _out.addByte(0xd9);
      _out.addByte(length);
    } else if (length < 0x10000) {
      _out.addByte(0xda);
      _writeUint16(length);
    } else {
      _out.addByte(0xdb);
      _writeUint32(length);
    }
    _out.add(bytes);
  }

  void _writeArrayHeader(int length) {
    if (length < 0x10) {
      _out.addByte(0x90 | length);
    } else if (length < 0x10000) {
      _out.addByte(0xdc);
      _writeUint16(length);
    } else {
      _out.addByte(0xdd);
      _writeUint32(length);
    }
  }

  void _writeMapHeader(int length) {
    if (length < 0x10) {
      _out.addByte(0x80 | length);
    } else if (length < 0x10000) {
      _out.addByte(0xde);
      _writeUint16(length);
    } else {
      _out.addByte(0xdf);
      _writeUint32(length);
    }
  }

  void _writeUint16(int value) {
    _out.addByte((value >> 8) & 0xff);
    _out.addByte(value & 0xff);
  }

  void _writeUint32(int value) {
    _out.addByte((value >> 24) & 0xff);
    _out.addByte((value >> 16) & 0xff);
    _out.addByte((value >> 8) & 0xff);
    _out.addByte(value & 0xff);
  }

  void _writeUint64(int value) {
    _writeUint32((value >> 32) & 0xffffffff);
    _writeUint32(value & 0xffffffff);
  }
}

Uint8List encodeMsgpack(Object? value) => MsgpackWriter().encode(value);

/// Reads a sequence of msgpack values from a buffer, tracking a cursor —
/// used to decode two back-to-back values out of one Colyseus ROOM_DATA
/// frame (the message "type", then the payload) without knowing either's
/// length up front.
class MsgpackReader {
  MsgpackReader(this.bytes, [this.offset = 0]);

  final Uint8List bytes;
  int offset;

  Object? readValue() {
    final byte = bytes[offset++];

    if (byte < 0x80) return byte; // positive fixint
    if (byte >= 0xe0) return byte - 0x100; // negative fixint
    if (byte >= 0xa0 && byte <= 0xbf) return _readString(byte & 0x1f);
    if (byte >= 0x90 && byte <= 0x9f) return _readArray(byte & 0x0f);
    if (byte >= 0x80 && byte <= 0x8f) return _readMap(byte & 0x0f);

    switch (byte) {
      case 0xc0:
        return null;
      case 0xc2:
        return false;
      case 0xc3:
        return true;
      case 0xcc:
        return _readUint(1);
      case 0xcd:
        return _readUint(2);
      case 0xce:
        return _readUint(4);
      case 0xcf:
        return _readUint(8);
      case 0xd0:
        return _readInt(1);
      case 0xd1:
        return _readInt(2);
      case 0xd2:
        return _readInt(4);
      case 0xd3:
        return _readInt(8);
      case 0xca:
        return _readFloat(4);
      case 0xcb:
        return _readFloat(8);
      case 0xd9:
        return _readString(_readUint(1));
      case 0xda:
        return _readString(_readUint(2));
      case 0xdb:
        return _readString(_readUint(4));
      case 0xdc:
        return _readArray(_readUint(2));
      case 0xdd:
        return _readArray(_readUint(4));
      case 0xde:
        return _readMap(_readUint(2));
      case 0xdf:
        return _readMap(_readUint(4));
      default:
        throw FormatException('Unsupported msgpack byte 0x${byte.toRadixString(16)} at offset ${offset - 1}');
    }
  }

  int _readUint(int byteLength) {
    var value = 0;
    for (var i = 0; i < byteLength; i++) {
      value = (value << 8) | bytes[offset++];
    }
    return value;
  }

  int _readInt(int byteLength) {
    final unsigned = _readUint(byteLength);
    final signBit = 1 << (byteLength * 8 - 1);
    return (unsigned & signBit) != 0 ? unsigned - (1 << (byteLength * 8)) : unsigned;
  }

  double _readFloat(int byteLength) {
    final view = ByteData.sublistView(bytes, offset, offset + byteLength);
    offset += byteLength;
    return byteLength == 4 ? view.getFloat32(0, Endian.big) : view.getFloat64(0, Endian.big);
  }

  String _readString(int length) {
    final value = utf8.decode(bytes.sublist(offset, offset + length));
    offset += length;
    return value;
  }

  List<Object?> _readArray(int length) => List.generate(length, (_) => readValue());

  Map<String, Object?> _readMap(int length) {
    final map = <String, Object?>{};
    for (var i = 0; i < length; i++) {
      final key = readValue() as String;
      map[key] = readValue();
    }
    return map;
  }
}

Object? decodeMsgpack(Uint8List bytes) => MsgpackReader(bytes).readValue();
