import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:himbil/net/leaderboard_service.dart';

void main() {
  test('liderlik listesi çözülür ve sıra korunur', () async {
    LeaderboardService.instance.clientFactory = () => MockClient((request) async {
          expect(request.url.path, '/leaderboard');
          return http.Response(
            '{"entries":[{"name":"Ayşe","points":200,"wins":2},{"name":"Mehmet","points":60,"wins":0}]}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

    final entries = await LeaderboardService.instance.fetch();
    expect(entries, isNotNull);
    expect(entries!.map((e) => e.name), ['Ayşe', 'Mehmet']);
    expect(entries.first.points, 200);
    expect(entries.first.wins, 2);
  });

  test('sunucu hatasında veya ulaşılamadığında null döner', () async {
    LeaderboardService.instance.clientFactory = () => MockClient((request) async => http.Response('down', 503));
    expect(await LeaderboardService.instance.fetch(), isNull);

    LeaderboardService.instance.clientFactory = () => MockClient((request) async => throw Exception('offline'));
    expect(await LeaderboardService.instance.fetch(), isNull);
  });
}
