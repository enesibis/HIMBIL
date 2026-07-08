import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/analytics/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSink implements AnalyticsSink {
  final List<MapEntry<String, Map<String, Object?>>> events = [];

  @override
  void record(String name, Map<String, Object?> params) => events.add(MapEntry(name, params));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('logEvent forwards to the sink synchronously', () {
    final sink = _FakeSink();
    final service = AnalyticsService(sink: sink);

    service.logEvent('round_completed', {'roundNumber': 1, 'durationMs': 4200});

    expect(sink.events, hasLength(1));
    expect(sink.events.single.key, 'round_completed');
    expect(sink.events.single.value, {'roundNumber': 1, 'durationMs': 4200});
  });

  group('D1/D7 retention', () {
    test('is false before the target day has ever been opened', () async {
      var now = DateTime(2026, 1, 1);
      final service = AnalyticsService(sink: _FakeSink(), now: () => now);

      await service.recordAppOpen();

      expect(await service.isDay1Active, isFalse);
      expect(await service.isDay7Active, isFalse);
    });

    test('becomes true once the app is opened again on day+1 / day+7', () async {
      var now = DateTime(2026, 1, 1);
      final service = AnalyticsService(sink: _FakeSink(), now: () => now);
      await service.recordAppOpen(); // first open (day 0)

      now = DateTime(2026, 1, 2);
      await service.recordAppOpen(); // day 1

      expect(await service.isDay1Active, isTrue);
      expect(await service.isDay7Active, isFalse);

      now = DateTime(2026, 1, 8);
      await service.recordAppOpen(); // day 7

      expect(await service.isDay7Active, isTrue);
    });

    test('a gap day does not retroactively count as day+1', () async {
      var now = DateTime(2026, 1, 1);
      final service = AnalyticsService(sink: _FakeSink(), now: () => now);
      await service.recordAppOpen(); // day 0

      now = DateTime(2026, 1, 3); // skipped day 1 entirely
      await service.recordAppOpen();

      expect(await service.isDay1Active, isFalse);
    });
  });
}
