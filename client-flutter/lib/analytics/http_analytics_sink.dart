import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../net/net_config.dart';
import '../session/guest_account_service.dart';
import 'analytics_service.dart';

/// Olayları sunucunun `POST /analytics/events` ucuna (madde #52'nin backend
/// yarısı) batch'leyerek akıtan [AnalyticsSink]. Tasarım ilkeleri:
///
/// - **Asla oyunu bekletmez / bozamaz:** `record` senkron kuyruğa yazar;
///   gönderim arka planda, hatalar sessiz. Sunucu yoksa (tam offline)
///   kuyruk sınırlı büyür ve en eskiler düşer — analitik kaybı kabul
///   edilebilir, oyun deneyimi değil.
/// - **Batch:** her olayda bir HTTP isteği atmak yerine eşik dolunca
///   (ya da [flush] çağrılınca) tek istekte gönderir.
/// - **Kimlik opsiyonel:** misafir hesabı kayıtlıysa olaylar o hesaba
///   etiketlenir; değilse anonim gider.
class HttpAnalyticsSink implements AnalyticsSink {
  HttpAnalyticsSink({http.Client Function()? clientFactory, this.flushThreshold = 10})
      : clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() clientFactory;
  final int flushThreshold;

  static const _maxQueued = 200;
  static const _maxPerBatch = 50; // sunucudaki MAX_EVENTS_PER_BATCH ile eşleşir
  static const _requestTimeout = Duration(seconds: 3);

  final List<Map<String, Object?>> _queue = [];
  bool _flushInFlight = false;

  int get queuedEventCount => _queue.length;

  @override
  void record(String name, Map<String, Object?> params) {
    _queue.add({'name': name, 'params': params, 'at': DateTime.now().toIso8601String()});
    while (_queue.length > _maxQueued) {
      _queue.removeAt(0);
    }
    if (_queue.length >= flushThreshold) unawaited(flush());
  }

  /// Kuyruğu (en fazla bir batch) gönderir. Başarısızlıkta olaylar kuyrukta
  /// kalır ve bir sonraki tetiklemede yeniden denenir.
  Future<void> flush() async {
    if (_flushInFlight || _queue.isEmpty) return;
    _flushInFlight = true;
    final batch = _queue.take(_maxPerBatch).toList();
    final client = clientFactory();
    try {
      final guest = GuestAccountService.instance;
      final response = await client
          .post(
            Uri.parse('${NetConfig.httpBaseUrl}/analytics/events'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'events': batch,
              if (guest.isRegistered) 'guestId': guest.guestId,
              if (guest.isRegistered) 'guestToken': guest.guestToken,
            }),
          )
          .timeout(_requestTimeout);
      if (response.statusCode == 200) {
        _queue.removeRange(0, batch.length);
      }
    } catch (_) {
      // sunucuya ulaşılamadı — olaylar kuyrukta, sonraki flush dener
    } finally {
      _flushInFlight = false;
      client.close();
    }
  }
}
