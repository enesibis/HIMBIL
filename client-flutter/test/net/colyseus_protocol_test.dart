import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/net/colyseus_protocol.dart';
import 'package:himbil/net/msgpack.dart';

void main() {
  group('encodeRoomData / decodeColyseusFrame round-trip', () {
    test('a message with a payload', () {
      final bytes = encodeRoomData('chooseCard', {'cardId': 7});
      final frame = decodeColyseusFrame(bytes) as RoomDataFrame;
      expect(frame.type, 'chooseCard');
      expect(frame.payload, {'cardId': 7});
    });

    test('a message with no payload', () {
      final bytes = encodeRoomData('slamPress');
      final frame = decodeColyseusFrame(bytes) as RoomDataFrame;
      expect(frame.type, 'slamPress');
      expect(frame.payload, isNull);
    });

    test('starts with the ROOM_DATA protocol byte', () {
      final bytes = encodeRoomData('slamPress');
      expect(bytes[0], ColyseusProtocol.roomData);
    });
  });

  group('decodeColyseusFrame', () {
    test('decodes a JOIN_ROOM handshake matching getMessageBytes[Protocol.JOIN_ROOM]\'s byte layout', () {
      // Mirrors server/node_modules/@colyseus/core/src/Protocol.ts's
      // getMessageBytes[Protocol.JOIN_ROOM]: [10, tokenLen, ...tokenBytes,
      // serializerLen, ...serializerBytes, ...optional handshake bytes].
      const token = 'abc123';
      const serializerId = 'none';
      final bytes = Uint8List.fromList([
        ColyseusProtocol.joinRoom,
        token.length,
        ...token.codeUnits,
        serializerId.length,
        ...serializerId.codeUnits,
      ]);

      final frame = decodeColyseusFrame(bytes) as JoinRoomFrame;
      expect(frame.reconnectionToken, token);
      expect(frame.serializerId, serializerId);
    });

    test('decodes an ERROR frame', () {
      final builder = BytesBuilder()
        ..addByte(ColyseusProtocol.error)
        ..add(encodeMsgpack(524))
        ..add(encodeMsgpack('room not found'));

      final frame = decodeColyseusFrame(builder.toBytes()) as ErrorFrame;
      expect(frame.code, 524);
      expect(frame.message, 'room not found');
    });

    test('decodes a PING frame', () {
      final frame = decodeColyseusFrame(Uint8List.fromList([ColyseusProtocol.ping]));
      expect(frame, isA<PingFrame>());
    });

    test('decodes a LEAVE_ROOM frame', () {
      final frame = decodeColyseusFrame(Uint8List.fromList([ColyseusProtocol.leaveRoom]));
      expect(frame, isA<LeaveRoomFrame>());
    });

    test('decodes an unrecognized protocol byte as UnknownFrame instead of throwing', () {
      final frame = decodeColyseusFrame(Uint8List.fromList([99])) as UnknownFrame;
      expect(frame.code, 99);
    });
  });

  test('encodeJoinRoomAck is exactly the single JOIN_ROOM protocol byte', () {
    expect(encodeJoinRoomAck(), Uint8List.fromList([ColyseusProtocol.joinRoom]));
  });
}
