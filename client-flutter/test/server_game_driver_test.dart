import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himbil/game/game_controller.dart';
import 'package:himbil/game/game_driver.dart';
import 'package:himbil/game/server_game_driver.dart';
import 'package:himbil/net/himbil_net_client.dart';
import 'package:himbil/session/player_session.dart';

/// Gerçek soket açmadan [ServerGameDriver]'ı beslemek için stream'leri
/// controller'lara bağlanmış sahte istemci. `chooseCard`/`pressSlam`
/// intent'lerini kaydeder ki sürücünün onları aynen ilettiği doğrulanabilsin.
class _FakeNetClient extends HimbilNetClient {
  final state = StreamController<Map<String, Object?>>.broadcast();
  final slam = StreamController<Map<String, Object?>>.broadcast();
  final roundScored = StreamController<Map<String, Object?>>.broadcast();
  final sentChooseCard = <int?>[];
  int slamPresses = 0;

  @override
  Stream<Map<String, Object?>> get stateUpdates => state.stream;

  @override
  Stream<Map<String, Object?>> get slamResults => slam.stream;

  @override
  Stream<Map<String, Object?>> get roundScoredEvents => roundScored.stream;

  @override
  Stream<String> get errors => const Stream.empty();

  @override
  void chooseCard(int? cardId) => sentChooseCard.add(cardId);

  @override
  void pressSlam() => slamPresses++;

  @override
  void dispose() {
    state.close();
    slam.close();
    roundScored.close();
  }
}

Map<String, Object?> _card(int id, String type) => {'id': id, 'objectType': type};

/// `RoomStateView` şeklinde bir state mesajı üretir. Koltuk testlerinde
/// oyuncu sırası [p0, me, p2, p3] — yani insan 1. indekste oturuyor.
Map<String, Object?> _state({
  String phase = 'swapping',
  int roundNumber = 0,
  List<Map<String, Object?>>? hand,
  List<String> slamOrder = const [],
  Object? swapTickDeadline,
  Object? slamWindowDeadline,
  Map<String, int> scores = const {},
}) {
  return {
    'roomCode': 'AB23CD',
    'phase': phase,
    'tickNumber': 0,
    'roundNumber': roundNumber,
    'direction': 1,
    'players': [
      {'id': 'p0', 'name': 'Kerem', 'handSize': 4, 'score': scores['p0'] ?? 0, 'connected': true},
      {'id': 'me', 'name': 'Ben', 'handSize': 4, 'score': scores['me'] ?? 0, 'connected': true},
      {'id': 'p2', 'name': 'Ayşe', 'handSize': 4, 'score': scores['p2'] ?? 0, 'connected': true},
      {'id': 'p3', 'name': 'Mehmet', 'handSize': 4, 'score': scores['p3'] ?? 0, 'connected': true},
    ],
    'you': {
      'id': 'me',
      'hand': hand ?? [_card(0, 'muz'), _card(1, 'uzum'), _card(2, 'cilek'), _card(3, 'portakal')],
    },
    'slamOrder': slamOrder,
    'slamWindowDeadline': slamWindowDeadline,
    'swapTickDeadline': swapTickDeadline,
    'targetScore': 300,
    'winnerId': null,
  };
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlayerSession.instance.load();
  });

  test('koltuk eşlemesi: oturma sırasına göre doğu/kuzey/batı bendeki indekse göredir', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);

    client.state.add(_state());
    await Future<void>.delayed(Duration.zero);

    // insan 1. indekste: doğu=+1 (p2), kuzey=+2 (p3), batı=+3 (p0)
    expect(driver.labelFor(Seat.human), 'Ben');
    expect(driver.labelFor(Seat.east), 'Ayşe');
    expect(driver.labelFor(Seat.north), 'Mehmet');
    expect(driver.labelFor(Seat.west), 'Kerem');

    driver.dispose();
  });

  test('ilk el -1 (yeni dağıtım), tek slot değişimi o slotu bildirir', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);
    final updates = <(List<Object?> ids, int changedSlot)>[];
    driver.onHandUpdated = (hand, slot) => updates.add(([for (final c in hand) c.id], slot));

    client.state.add(_state());
    await Future<void>.delayed(Duration.zero);
    expect(updates.single.$2, -1);

    // takas tick'i: yalnız 1. slot değişti (id 1 → 9)
    client.state.add(_state(hand: [_card(0, 'muz'), _card(9, 'muz'), _card(2, 'cilek'), _card(3, 'portakal')]));
    await Future<void>.delayed(Duration.zero);
    expect(updates.last.$2, 1);
    expect(updates.last.$1, [0, 9, 2, 3]);

    // el değişmeden gelen yayın (başka oyuncunun slam'ı vb.) tekrar bildirmez
    client.state.add(_state(hand: [_card(0, 'muz'), _card(9, 'muz'), _card(2, 'cilek'), _card(3, 'portakal')]));
    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(2));

    // yeni tur numarası = tam yenileme (-1)
    client.state.add(_state(roundNumber: 1, hand: [_card(4, 'uzum'), _card(5, 'uzum'), _card(6, 'cilek'), _card(7, 'muz')]));
    await Future<void>.delayed(Duration.zero);
    expect(updates.last.$2, -1);

    driver.dispose();
  });

  test('slamOrder farkları koltuk bazında onSlamAttemptRecorded üretir', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);
    final seats = <Seat>[];
    driver.onSlamAttemptRecorded = seats.add;

    client.state.add(_state(phase: 'slamWindow', slamOrder: ['p2']));
    await Future<void>.delayed(Duration.zero);
    client.state.add(_state(phase: 'slamWindow', slamOrder: ['p2', 'me', 'p0']));
    await Future<void>.delayed(Duration.zero);

    expect(seats, [Seat.east, Seat.human, Seat.west]);
    driver.dispose();
  });

  test('roundScored: sıralama etiketleri, skor senkronu ve kazanana jeton ödülü', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);
    (int, List<RoundRankEntry>, Seat?)? scored;
    int? tokens;
    driver.onRoundScored = (round, entries, winner) => scored = (round, entries, winner);
    driver.onMatchTokensAwarded = (amount) => tokens = amount;

    client.state.add(_state());
    await Future<void>.delayed(Duration.zero);

    client.roundScored.add({
      'roundNumber': 3,
      'results': [
        {'playerId': 'me', 'score': 100},
        {'playerId': 'p2', 'score': 75},
      ],
      'totals': [
        {'playerId': 'p0', 'score': 50},
        {'playerId': 'me', 'score': 300},
        {'playerId': 'p2', 'score': 150},
        {'playerId': 'p3', 'score': 0},
      ],
      'winnerId': 'me',
    });
    await Future<void>.delayed(Duration.zero);

    expect(scored, isNotNull);
    expect(scored!.$1, 3);
    expect(scored!.$2.map((e) => e.label), ['Ben', 'Ayşe']);
    expect(scored!.$3, Seat.human);
    expect(driver.scoreOf(Seat.human), 300);
    expect(driver.scoreOf(Seat.east), 150);
    // maç birincisi: placementTokenRewards[0]
    expect(tokens, GameController.placementTokenRewards[0]);

    driver.dispose();
  });

  test('slamPressResult mesajı SlamOutcome olarak iletilir, intentler istemciye gider', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);
    final outcomes = <SlamOutcome>[];
    driver.onSlamOutcome = outcomes.add;

    driver.chooseCard(7);
    driver.pressSlam();
    expect(client.sentChooseCard, [7]);
    expect(client.slamPresses, 1);

    client.slam.add({'outcome': 'tooEarly'});
    client.slam.add({'outcome': 'falseStart'});
    client.slam.add({'outcome': 'recorded'});
    await Future<void>.delayed(Duration.zero);
    expect(outcomes, [SlamOutcome.tooEarly, SlamOutcome.falseStart, SlamOutcome.recorded]);

    driver.dispose();
  });

  test('deadline geri sayımı: gelecekteki deadline pozitif kalan süre üretir', () async {
    final client = _FakeNetClient();
    final driver = ServerGameDriver(client);
    final ticks = <double>[];
    driver.onCountdownTick = (seconds, max) => ticks.add(seconds);

    final deadline = DateTime.now().millisecondsSinceEpoch + 2000;
    client.state.add(_state(swapTickDeadline: deadline));
    await Future<void>.delayed(Duration.zero);

    expect(ticks, isNotEmpty);
    expect(ticks.last, greaterThan(0));
    expect(ticks.last, lessThanOrEqualTo(2.05));

    driver.dispose();
  });
}
