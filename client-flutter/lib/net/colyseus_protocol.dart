import 'dart:typed_data';

import 'msgpack.dart';

/// Colyseus wire protocol codes this client needs (see
/// server/schema/messages.ts for why this is hand-implemented rather than
/// depending on an official client SDK — there isn't one for Dart/Flutter).
/// Values verified against the installed `@colyseus/shared-types` package's
/// `Protocol` enum, not guessed.
class ColyseusProtocol {
  static const int joinRoom = 10;
  static const int error = 11;
  static const int leaveRoom = 12;
  static const int roomData = 13;
  static const int roomDataBytes = 17;
  static const int ping = 18;
}

sealed class ColyseusFrame {}

/// Sent by the server right after a WebSocket connects and the seat
/// reservation is consumed. The client must reply with [encodeJoinRoomAck]
/// — until it does, the server queues (never sends) any `state`/other
/// messages, since from the server's perspective the client hasn't
/// registered its message listeners yet.
class JoinRoomFrame extends ColyseusFrame {
  JoinRoomFrame(this.reconnectionToken, this.serializerId);
  final String reconnectionToken;
  final String serializerId;
}

class RoomDataFrame extends ColyseusFrame {
  RoomDataFrame(this.type, this.payload);
  final String type;
  final Object? payload;
}

class ErrorFrame extends ColyseusFrame {
  ErrorFrame(this.code, this.message);
  final int code;
  final String message;
}

class LeaveRoomFrame extends ColyseusFrame {}

class PingFrame extends ColyseusFrame {}

class UnknownFrame extends ColyseusFrame {
  UnknownFrame(this.code);
  final int code;
}

ColyseusFrame decodeColyseusFrame(Uint8List bytes) {
  final code = bytes[0];
  switch (code) {
    case ColyseusProtocol.joinRoom:
      var offset = 1;
      final tokenLength = bytes[offset++];
      final token = String.fromCharCodes(bytes, offset, offset + tokenLength);
      offset += tokenLength;
      final serializerLength = bytes[offset++];
      final serializerId = String.fromCharCodes(bytes, offset, offset + serializerLength);
      // Any remaining bytes are a `@colyseus/schema` state handshake, which
      // this room never sends (no synced `state`, see messages.ts).
      return JoinRoomFrame(token, serializerId);

    case ColyseusProtocol.error:
      final reader = MsgpackReader(bytes, 1);
      final errorCode = reader.readValue() as int;
      final message = (reader.offset < bytes.length ? reader.readValue() as String? : null) ?? '';
      return ErrorFrame(errorCode, message);

    case ColyseusProtocol.leaveRoom:
      return LeaveRoomFrame();

    case ColyseusProtocol.roomData:
    case ColyseusProtocol.roomDataBytes:
      final reader = MsgpackReader(bytes, 1);
      final type = reader.readValue() as String;
      final payload = reader.offset < bytes.length ? reader.readValue() : null;
      return RoomDataFrame(type, payload);

    case ColyseusProtocol.ping:
      return PingFrame();

    default:
      return UnknownFrame(code);
  }
}

/// Encodes a `client.send(type, payload)`-compatible ROOM_DATA frame.
Uint8List encodeRoomData(String type, [Object? payload]) {
  final builder = BytesBuilder(copy: false);
  builder.addByte(ColyseusProtocol.roomData);
  builder.add(encodeMsgpack(type));
  if (payload != null) {
    builder.add(encodeMsgpack(payload));
  }
  return builder.toBytes();
}

/// The handshake reply that flips the server-side client state from
/// JOINING to JOINED. No payload: the server only checks the protocol byte.
Uint8List encodeJoinRoomAck() => Uint8List.fromList([ColyseusProtocol.joinRoom]);
