// Uçtan uca online maç doğrulaması — gerçek Colyseus sunucusuna karşı
// 4 istemciyle: oda kur → kodla katıl ×3 → otomatik başlama → akıllı kart
// seçimiyle takas tick'leri → 4'lü oluşunca slam yarışı (pile-on dahil,
// pencere erken kapanır) → roundScored yayını → scoring molası → yeni tur.
//
// Çalıştırma (sunucu ayakta olmalı: server/ içinde `npm run dev`):
//   cd client-flutter && dart run tool/e2e_online_match.dart
//
// Flutter'a bağımlı DEĞİLDİR (saf Dart): CI'da ya da lokalde `dart run` ile
// koşar. Başarıda 0, hatada 1 döner.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:himbil/net/himbil_net_client.dart';

const _matchTimeout = Duration(seconds: 120);

Future<void> main() async {
  try {
    await _run().timeout(_matchTimeout);
    stdout.writeln('E2E OK');
    exit(0);
  } catch (e, st) {
    stderr.writeln('E2E FAILED: $e\n$st');
    exit(1);
  }
}

Future<void> _run() async {
  final clients = [for (var i = 0; i < 4; i++) _TestPlayer('P$i')];

  // 1) P0 oda kurar, kodu öğrenir.
  await clients[0].client.createRoom(name: clients[0].name);
  final roomCode = (await clients[0].nextState((s) => s['roomCode'] != null))['roomCode'] as String;
  stdout.writeln('oda kuruldu: $roomCode');

  // 2) Diğerleri kodla katılır; 4. katılımda sunucu maçı kendisi başlatır.
  for (final p in clients.skip(1)) {
    await p.client.joinByCode(roomCode, name: p.name);
  }
  for (final p in clients) {
    final state = await p.nextState((s) => s['phase'] == 'swapping');
    final hand = _handOf(state);
    if (hand.length != 4) throw StateError('${p.name}: el 4 kart değil: $hand');
    // El sızıntısı kontrolü: players[] girdilerinde hand alanı OLMAMALI.
    for (final entry in (state['players'] as List)) {
      if ((entry as Map).containsKey('hand')) {
        throw StateError('${p.name}: rakip eli sızdı!');
      }
    }
    if ((state['swapTickDeadline'] as num?) == null) {
      throw StateError('${p.name}: swapping state swapTickDeadline taşımıyor');
    }
  }
  stdout.writeln('maç başladı, eller dağıtıldı, sızıntı yok, swap deadline geldi');

  // 3) Her istemci state akışına strateji bağlar: takasta en az işe yarayan
  //    kartı ver; pencerede 4'lün varsa bas, yoksa ilk basışı görünce bas.
  for (final p in clients) {
    p.startPlaying();
  }

  // 4) İlk roundScored yayını: sıralama + toplamlar dolu olmalı.
  final scored = await clients[0].roundScored.first.timeout(const Duration(seconds: 90));
  final results = (scored['results'] as List);
  final totals = (scored['totals'] as List);
  if (results.isEmpty) throw StateError('roundScored.results boş');
  if (totals.length != 4) throw StateError('roundScored.totals 4 oyuncu değil: $totals');
  stdout.writeln('tur skorlandı: ${results.length} basış, kazanan: ${scored['winnerId']}');

  // 5) Scoring molasından sonra yeni tur kendiliğinden dağıtılmalı.
  if (scored['winnerId'] == null) {
    final next = await clients[0]
        .nextState((s) => s['phase'] == 'swapping' && (s['roundNumber'] as num).toInt() >= 1)
        .timeout(const Duration(seconds: 15));
    if (_handOf(next).length != 4) throw StateError('yeni tur eli dağıtılmadı');
    stdout.writeln('scoring molası sonrası yeni tur dağıtıldı (tur ${(next['roundNumber'] as num).toInt() + 1})');
  } else {
    stdout.writeln('maç ilk turda bitti (winnerId=${scored['winnerId']}) — mola dalı atlandı');
  }

  for (final p in clients) {
    await p.client.disconnect();
    p.dispose();
  }
}

List<Map<String, Object?>> _handOf(Map<String, Object?> state) {
  final you = (state['you'] as Map).cast<String, Object?>();
  return [for (final c in (you['hand'] as List)) (c as Map).cast<String, Object?>()];
}

class _TestPlayer {
  _TestPlayer(this.name) {
    _sub = client.stateUpdates.listen((state) {
      _lastState = state;
      for (final waiter in List.of(_waiters)) {
        if (waiter.predicate(state)) {
          _waiters.remove(waiter);
          waiter.completer.complete(state);
        }
      }
      if (_playing) _react(state);
    });
  }

  final String name;
  final client = HimbilNetClient();
  late final StreamSubscription<Map<String, Object?>> _sub;
  final _waiters = <({bool Function(Map<String, Object?>) predicate, Completer<Map<String, Object?>> completer})>[];
  Map<String, Object?>? _lastState;
  bool _playing = false;
  int _lastChosenTick = -1;
  bool _pressedThisWindow = false;
  String? _lastWindowKey;

  Stream<Map<String, Object?>> get roundScored => client.roundScoredEvents;

  Future<Map<String, Object?>> nextState(bool Function(Map<String, Object?>) predicate) {
    final last = _lastState;
    if (last != null && predicate(last)) return Future.value(last);
    final completer = Completer<Map<String, Object?>>();
    _waiters.add((predicate: predicate, completer: completer));
    return completer.future;
  }

  void startPlaying() {
    _playing = true;
    final last = _lastState;
    if (last != null) _react(last);
  }

  void _react(Map<String, Object?> state) {
    final phase = state['phase'] as String?;
    final tick = (state['tickNumber'] as num?)?.toInt() ?? 0;

    if (phase == 'swapping') {
      _pressedThisWindow = false;
      if (tick == _lastChosenTick) return;
      _lastChosenTick = tick;
      client.chooseCard(_leastUsefulCardId(_handOf(state)));
      return;
    }

    if (phase == 'slamWindow') {
      final windowKey = '${state['roundNumber']}:$tick';
      if (windowKey != _lastWindowKey) {
        _lastWindowKey = windowKey;
        _pressedThisWindow = false;
      }
      if (_pressedThisWindow) return;
      final hand = _handOf(state);
      final hasQuartet = hand.every((c) => c['objectType'] == hand.first['objectType']);
      final someonePressed = ((state['slamOrder'] as List?) ?? const []).isNotEmpty;
      if (hasQuartet || someonePressed) {
        _pressedThisWindow = true;
        client.pressSlam();
      }
    }
  }

  /// BotAI.decideCardToPass ile aynı fikir: elde en az tekrar eden türden
  /// bir kart — 4'lüye giden kartları elde tutar, maçı hızla sonuca götürür.
  int _leastUsefulCardId(List<Map<String, Object?>> hand) {
    final counts = <String, int>{};
    for (final card in hand) {
      final type = card['objectType'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final minCount = counts.values.reduce(math.min);
    final candidates = [for (final c in hand) if (counts[c['objectType']] == minCount) c];
    return ((candidates[math.Random().nextInt(candidates.length)])['id'] as num).toInt();
  }

  void dispose() {
    _sub.cancel();
    client.dispose();
  }
}
