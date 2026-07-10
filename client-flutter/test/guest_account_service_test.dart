import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himbil/session/guest_account_service.dart';

void main() {
  late GuestAccountService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = GuestAccountService.instance = GuestAccountService.instance;
    // Her test taze bir singleton durumuyla başlasın.
    service.guestId = null;
    service.guestToken = null;
    await service.load();
  });

  test('kayıt başarılıysa kimlik saklanır ve ikinci çağrı istek atmaz', () async {
    var registerCalls = 0;
    service.clientFactory = () => MockClient((request) async {
          registerCalls++;
          expect(request.url.path, '/guest/register');
          return http.Response(jsonEncode({'guestId': 'g-1', 'guestToken': 't-1'}), 200);
        });

    await service.ensureRegistered();
    expect(service.isRegistered, isTrue);
    expect(service.guestId, 'g-1');

    await service.ensureRegistered();
    expect(registerCalls, 1, reason: 'kayıtlıyken tekrar register çağrılmamalı');

    // kalıcılık: yeni instance yükleyince kimlik geri gelmeli
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guest_id'), 'g-1');
    expect(prefs.getString('guest_token'), 't-1');
  });

  test('kayıt başarısızsa sessizce kayıtsız kalır (offline tolere edilir)', () async {
    service.clientFactory = () => MockClient((request) async => http.Response('down', 503));
    await service.ensureRegistered();
    expect(service.isRegistered, isFalse);
  });

  test('fetchMe bakiye + envanteri çözer', () async {
    service.guestId = 'g-1';
    service.guestToken = 't-1';
    service.clientFactory = () => MockClient((request) async {
          expect(request.url.path, '/guest/me');
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['guestId'], 'g-1');
          return http.Response(jsonEncode({'balance': 720, 'inventory': ['nazar', 'kilim']}), 200);
        });

    final me = await service.fetchMe();
    expect(me, isNotNull);
    expect(me!.balance, 720);
    expect(me.inventory, ['nazar', 'kilim']);
  });

  test('fetchMe kayıtsızken veya 401 dönünce null verir', () async {
    expect(await service.fetchMe(), isNull);

    service.guestId = 'g-1';
    service.guestToken = 'yanlis';
    service.clientFactory = () => MockClient((request) async => http.Response('{"error":"x"}', 401));
    expect(await service.fetchMe(), isNull);
  });
}
