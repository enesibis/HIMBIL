import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../net/net_config.dart';

/// Sunucudaki misafir-hesap API'sinin (server/routes/guestRoutes.ts) client
/// ucu — madde #60'ın "PlayerSession'ı sunucuya bağla" geçişinin ilk adımı.
///
/// Ne yapar: sunucuya ulaşılabilen ilk fırsatta bir kez misafir hesabı
/// açar (`POST /guest/register`), kimliği cihazda saklar ve online maç
/// katılımlarında odaya iletilmek üzere sunar; oda, maç sonu ödüllerini bu
/// kimliğin sunucu-taraflı jeton defterine yazar (HimbilRoom).
///
/// Ne yapmaz (bilinçli): cihaz-yerel `PlayerSession` bakiyesini değiştirmez.
/// Oyun içi ekonomi geçiş tamamlanana kadar yerelde çalışmaya devam eder;
/// sunucu defteri, tam geçişte mutabakat yapılacak yetkili kayıt + denetim
/// izidir. Sunucu tasarımı gereği client'ın kendi bakiyesini yazabileceği
/// bir uç yoktur.
class GuestAccountService {
  GuestAccountService._();

  static GuestAccountService instance = GuestAccountService._();

  static const _keyGuestId = 'guest_id';
  static const _keyGuestToken = 'guest_token';
  static const _requestTimeout = Duration(seconds: 3);

  /// Test dikişi — testler `package:http/testing` MockClient enjekte eder.
  http.Client Function() clientFactory = http.Client.new;

  String? guestId;
  String? guestToken;

  bool get isRegistered => guestId != null && guestToken != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    guestId = prefs.getString(_keyGuestId);
    guestToken = prefs.getString(_keyGuestToken);
  }

  /// Kayıtlı değilse sunucuda misafir hesabı açmayı dener. Her türlü
  /// başarısızlık sessizce yutulur — offline mod uygulamanın her zaman
  /// çalışan tabanı, kayıt bir sonraki online denemede tekrar denenir.
  Future<void> ensureRegistered() async {
    if (isRegistered) return;
    final client = clientFactory();
    try {
      final response = await client
          .post(Uri.parse('${NetConfig.httpBaseUrl}/guest/register'))
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, Object?>;
      final id = data['guestId'];
      final token = data['guestToken'];
      if (id is! String || token is! String) return;
      guestId = id;
      guestToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGuestId, id);
      await prefs.setString(_keyGuestToken, token);
    } catch (_) {
      // sunucuya ulaşılamadı / zaman aşımı — sonraki denemeye bırak
    } finally {
      client.close();
    }
  }

  /// Sunucu defterindeki bakiye + envanter. Kayıtlı değilsek ya da istek
  /// başarısızsa null (çağıran yerel değerleri göstermeye devam eder).
  Future<({int balance, List<String> inventory})?> fetchMe() async {
    if (!isRegistered) return null;
    final client = clientFactory();
    try {
      final response = await client
          .post(
            Uri.parse('${NetConfig.httpBaseUrl}/guest/me'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'guestId': guestId, 'guestToken': guestToken}),
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, Object?>;
      return (
        balance: (data['balance'] as num?)?.toInt() ?? 0,
        inventory: ((data['inventory'] as List?) ?? const []).cast<String>(),
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}
