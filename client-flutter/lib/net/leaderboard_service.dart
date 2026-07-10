import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'net_config.dart';

class LeaderboardEntry {
  final String name;
  final int points;
  final int wins;

  const LeaderboardEntry({required this.name, required this.points, required this.wins});
}

/// Sunucunun herkese açık `GET /leaderboard` ucunun client'ı (madde #61
/// devamı). Sıralama sunucu defterindeki online maç ödüllerinden türediği
/// için buradan gelen liste hilelenemez; sunucuya ulaşılamazsa null döner
/// ve Profil sekmesi "Yakında" durumunu göstermeye devam eder.
class LeaderboardService {
  LeaderboardService._();

  static LeaderboardService instance = LeaderboardService._();

  static const _requestTimeout = Duration(seconds: 3);

  /// Test dikişi — testler MockClient enjekte eder.
  http.Client Function() clientFactory = http.Client.new;

  Future<List<LeaderboardEntry>?> fetch() async {
    final client = clientFactory();
    try {
      final response = await client.get(Uri.parse('${NetConfig.httpBaseUrl}/leaderboard')).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, Object?>;
      final entries = (data['entries'] as List?) ?? const [];
      return [
        for (final entry in entries)
          LeaderboardEntry(
            name: ((entry as Map)['name'] as String?) ?? 'Oyuncu',
            points: (entry['points'] as num?)?.toInt() ?? 0,
            wins: (entry['wins'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
