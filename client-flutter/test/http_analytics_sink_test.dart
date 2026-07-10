import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himbil/analytics/http_analytics_sink.dart';
import 'package:himbil/session/guest_account_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GuestAccountService.instance.guestId = null;
    GuestAccountService.instance.guestToken = null;
  });

  test('eşik dolunca tek batch halinde gönderir ve kuyruğu boşaltır', () async {
    final batches = <Map<String, Object?>>[];
    final sink = HttpAnalyticsSink(
      flushThreshold: 3,
      clientFactory: () => MockClient((request) async {
        expect(request.url.path, '/analytics/events');
        batches.add(jsonDecode(request.body) as Map<String, Object?>);
        return http.Response('{"accepted":3}', 200);
      }),
    );

    sink.record('a', {});
    sink.record('b', {});
    expect(batches, isEmpty, reason: 'eşik dolmadan istek atılmamalı');
    sink.record('c', {'x': 1});
    await Future<void>.delayed(Duration.zero);

    expect(batches, hasLength(1));
    final events = batches.single['events'] as List;
    expect(events, hasLength(3));
    expect((events[2] as Map)['name'], 'c');
    expect(batches.single.containsKey('guestId'), isFalse, reason: 'kayıtsızken kimlik eklenmemeli');
    expect(sink.queuedEventCount, 0);
  });

  test('gönderim başarısızsa olaylar kuyrukta kalır ve sonraki flush yeniden dener', () async {
    var attempts = 0;
    final sink = HttpAnalyticsSink(
      flushThreshold: 100,
      clientFactory: () => MockClient((request) async {
        attempts++;
        if (attempts == 1) return http.Response('down', 503);
        return http.Response('{"accepted":1}', 200);
      }),
    );

    sink.record('kept', {});
    await sink.flush();
    expect(sink.queuedEventCount, 1, reason: '503 sonrası olay düşmemeli');

    await sink.flush();
    expect(sink.queuedEventCount, 0);
    expect(attempts, 2);
  });

  test('misafir hesabı kayıtlıysa kimlik batch\'e eklenir', () async {
    GuestAccountService.instance.guestId = 'g-9';
    GuestAccountService.instance.guestToken = 't-9';
    Map<String, Object?>? sent;
    final sink = HttpAnalyticsSink(
      flushThreshold: 100,
      clientFactory: () => MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response('{"accepted":1}', 200);
      }),
    );

    sink.record('tagged', {});
    await sink.flush();
    expect(sent!['guestId'], 'g-9');
    expect(sent!['guestToken'], 't-9');
  });
}
