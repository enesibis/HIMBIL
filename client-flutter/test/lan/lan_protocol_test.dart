import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/game/lan/lan_protocol.dart';

void main() {
  group('LanFraming/LanFrameDecoder', () {
    test('round-trips a single message', () async {
      final decoder = LanFrameDecoder();
      final received = <Map<String, Object?>>[];
      decoder.messages.listen(received.add);

      decoder.add(LanFraming.encode({'type': 'chooseCard', 'cardId': 42}));
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'chooseCard', 'cardId': 42},
      ]);
    });

    test('handles a message split across multiple chunks (TCP fragmentation)', () async {
      final decoder = LanFrameDecoder();
      final received = <Map<String, Object?>>[];
      decoder.messages.listen(received.add);

      final bytes = LanFraming.encode({'type': 'state', 'phase': 'swapping'});
      final mid = bytes.length ~/ 2;
      decoder.add(bytes.sublist(0, mid));
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty, reason: 'incomplete frame should not emit yet');

      decoder.add(bytes.sublist(mid));
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'state', 'phase': 'swapping'},
      ]);
    });

    test('handles two messages arriving in a single chunk (TCP coalescing)', () async {
      final decoder = LanFrameDecoder();
      final received = <Map<String, Object?>>[];
      decoder.messages.listen(received.add);

      final combined = [
        ...LanFraming.encode({'type': 'a'}),
        ...LanFraming.encode({'type': 'b'}),
      ];
      decoder.add(combined);
      await Future<void>.delayed(Duration.zero);

      expect(received, [
        {'type': 'a'},
        {'type': 'b'},
      ]);
    });

    test('round-trips nested maps/lists (a RoomStateView-shaped payload)', () async {
      final decoder = LanFrameDecoder();
      final received = <Map<String, Object?>>[];
      decoder.messages.listen(received.add);

      final payload = {
        'type': 'state',
        'phase': 'slamWindow',
        'players': [
          {'id': 'p0', 'name': 'Ayşe', 'score': 100, 'connected': true, 'idle': false},
        ],
        'slamOrder': <String>['p0'],
        'slamWindowDeadline': 1700000000000,
        'winnerId': null,
      };
      decoder.add(LanFraming.encode(payload));
      await Future<void>.delayed(Duration.zero);

      expect(received.single, payload);
    });
  });
}
