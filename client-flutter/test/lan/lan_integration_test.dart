import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/game/game_controller.dart';
import 'package:himbil/game/lan/lan_game_driver.dart';
import 'package:himbil/game/lan/lan_host_server.dart';
import 'package:himbil/game/rules.dart';
import 'package:himbil/session/player_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uydurma bir port + UDP keşif kapalı: host+3 misafirin gerçek bir
/// `127.0.0.1` TCP bağlantısı üzerinden uçtan uca oynaması — birim
/// testlerinin aksine, [LanHostServer]/[LanGameDriver] çiftinin gerçekten
/// bir soket açıp veri alışverişi yaptığını kanıtlar.
const _testPort = 45999;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerSession.instance = PlayerSession();
  });

  test('host + 3 misafir gerçek bir yerel soket üzerinden bağlanır ve maç başlar', () async {
    final server = LanHostServer(
      hostName: 'Host',
      roomName: 'Test Odası',
      tcpPort: _testPort,
      enableDiscovery: false,
    );
    await server.start();
    addTearDown(server.dispose);

    final hostDriver = LanGameDriver.host(server, hostName: 'Host');
    addTearDown(hostDriver.dispose);

    final guestDrivers = <LanGameDriver>[];
    addTearDown(() {
      for (final d in guestDrivers) {
        d.dispose();
      }
    });

    for (var i = 0; i < 3; i++) {
      final guest = await LanGameDriver.connectAsGuest(
        address: InternetAddress.loopbackIPv4,
        port: _testPort,
        name: 'Misafir$i',
      );
      guestDrivers.add(guest);
    }

    // 4. oyuncu (3. misafir) katılınca host otomatik başlatmalı. Host'un
    // kendi state broadcast'i process-içi (StreamController, mikrotask ile
    // anında işlenir), ama misafirlerinki gerçek bir TCP soketten geliyor —
    // gerçek I/O gecikmesi (event loop'un bir kez daha dönmesi) gerektirir,
    // bu yüzden HER sürücü için ayrı ayrı "faz değişti" bekleniyor; yalnız
    // host'u beklemek misafirlerin verisi henüz gelmeden kontrol etmeye
    // (ve sahte bir başarısızlığa) yol açar.
    final allDrivers = [hostDriver, ...guestDrivers];
    final matchStarted = [for (final _ in allDrivers) Completer<void>()];
    for (var i = 0; i < allDrivers.length; i++) {
      allDrivers[i].onPhaseChanged = (phase) {
        if (phase != GamePhase.waiting && !matchStarted[i].isCompleted) matchStarted[i].complete();
      };
    }
    for (final driver in allDrivers) {
      driver.start();
    }
    await Future.wait([for (final c in matchStarted) c.future]).timeout(const Duration(seconds: 5));

    // Her sürücü kendi 4 kartlık elini almış olmalı — start() zaten bilinen
    // son eli senkron olarak yeniden bildirir (bkz. LanGameDriver.start).
    for (var i = 0; i < allDrivers.length; i++) {
      expect(allDrivers[i].phase, GamePhase.swapping, reason: 'driver[$i]');
      List<CardModel>? hand;
      allDrivers[i].onHandUpdated = (h, _) => hand = h;
      allDrivers[i].start();
      expect(hand, hasLength(4), reason: 'driver[$i]');
    }
  });
}
