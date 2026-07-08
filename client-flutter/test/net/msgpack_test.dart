import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/net/msgpack.dart';

void main() {
  group('MsgpackWriter/decodeMsgpack round-trip', () {
    test('null', () {
      expect(decodeMsgpack(encodeMsgpack(null)), isNull);
    });

    test('booleans', () {
      expect(decodeMsgpack(encodeMsgpack(true)), true);
      expect(decodeMsgpack(encodeMsgpack(false)), false);
    });

    test('small positive fixint', () {
      expect(decodeMsgpack(encodeMsgpack(5)), 5);
      expect(decodeMsgpack(encodeMsgpack(0)), 0);
      expect(decodeMsgpack(encodeMsgpack(127)), 127);
    });

    test('small negative fixint', () {
      expect(decodeMsgpack(encodeMsgpack(-1)), -1);
      expect(decodeMsgpack(encodeMsgpack(-25)), -25);
      expect(decodeMsgpack(encodeMsgpack(-32)), -32);
    });

    test('ints across uint8/16/32 boundaries', () {
      for (final value in [200, 1000, 70000, 5000000000]) {
        expect(decodeMsgpack(encodeMsgpack(value)), value, reason: 'value=$value');
      }
    });

    test('ints across int8/16/32 boundaries', () {
      for (final value in [-100, -1000, -70000, -5000000000]) {
        expect(decodeMsgpack(encodeMsgpack(value)), value, reason: 'value=$value');
      }
    });

    test('a realistic epoch-millisecond deadline round-trips exactly', () {
      final deadline = DateTime.now().millisecondsSinceEpoch + 4000;
      expect(decodeMsgpack(encodeMsgpack(deadline)), deadline);
    });

    test('doubles', () {
      expect(decodeMsgpack(encodeMsgpack(1.5)), 1.5);
      expect(decodeMsgpack(encodeMsgpack(-3.25)), -3.25);
    });

    test('strings of varying length (fixstr/str8/str16 boundaries)', () {
      for (final length in [0, 5, 31, 32, 255, 256, 1000]) {
        final value = 'a' * length;
        expect(decodeMsgpack(encodeMsgpack(value)), value, reason: 'length=$length');
      }
    });

    test('strings with non-ASCII (Turkish) characters', () {
      const value = 'Hımbıl Şeftali Çilek';
      expect(decodeMsgpack(encodeMsgpack(value)), value);
    });

    test('lists of primitives', () {
      final value = [1, 'elma', true, null, -5];
      expect(decodeMsgpack(encodeMsgpack(value)), value);
    });

    test('a list long enough to require array16 header', () {
      final value = List.generate(20, (i) => i);
      expect(decodeMsgpack(encodeMsgpack(value)), value);
    });

    test('maps of primitives', () {
      final value = {'type': 'chooseCard', 'cardId': 7};
      expect(decodeMsgpack(encodeMsgpack(value)), value);
    });

    test('nested maps and lists (a RoomStateView-shaped payload)', () {
      final value = {
        'roomCode': 'AB12CD',
        'phase': 'slamWindow',
        'tickNumber': 3,
        'direction': 1,
        'players': [
          {'id': 'p0', 'name': 'Ayşe', 'handSize': 4, 'score': 100, 'connected': true},
          {'id': 'p1', 'name': 'Mehmet', 'handSize': 4, 'score': 0, 'connected': false},
        ],
        'you': {
          'id': 'p0',
          'hand': [
            {'id': 4, 'objectType': 'armut'},
            {'id': 7, 'objectType': 'armut'},
          ],
        },
        'slamOrder': <String>[],
        'slamWindowDeadline': 1794000004000,
        'targetScore': 300,
        'winnerId': null,
      };

      expect(decodeMsgpack(encodeMsgpack(value)), value);
    });
  });
}
