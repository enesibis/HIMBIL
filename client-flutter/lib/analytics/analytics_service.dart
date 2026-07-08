import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where analytics events actually go. No backend exists yet (madde #52),
/// so the default sink just logs locally — swapping in a real one (Firebase
/// Analytics, Amplitude, a self-hosted endpoint) later means replacing this,
/// not touching any call site.
abstract class AnalyticsSink {
  void record(String name, Map<String, Object?> params);
}

class DebugPrintSink implements AnalyticsSink {
  const DebugPrintSink();

  @override
  void record(String name, Map<String, Object?> params) {
    // ignore: avoid_print
    print('[analytics] $name $params');
  }
}

/// Local-only analytics: turn duration, false-slam rate, and D1/D7
/// retention (madde #52), so balance decisions ("is the false-slam penalty
/// too harsh?") have real numbers behind them even before a backend exists.
/// Events are appended to a bounded local ring buffer (inspectable/
/// exportable later) instead of being silently dropped.
///
/// Swappable singleton (same pattern as `PlayerSession.instance` — see
/// yapılması-gerekenler #25) so tests can substitute their own instance.
class AnalyticsService {
  AnalyticsService({AnalyticsSink sink = const DebugPrintSink(), DateTime Function() now = DateTime.now})
      : _sink = sink,
        _now = now;

  static AnalyticsService instance = AnalyticsService();

  final AnalyticsSink _sink;
  final DateTime Function() _now;

  static const _activeDaysKey = 'analytics_active_days';
  static const _firstOpenKey = 'analytics_first_open_day';
  static const _eventsKey = 'analytics_events_log';
  static const _maxStoredEvents = 200;

  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    _sink.record(name, params);
    _appendToLocalLog(name, params);
  }

  Future<void> _appendToLocalLog(String name, Map<String, Object?> params) async {
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList(_eventsKey) ?? <String>[];
    log.add(jsonEncode({'name': name, 'params': params, 'at': _now().toIso8601String()}));
    while (log.length > _maxStoredEvents) {
      log.removeAt(0);
    }
    await prefs.setStringList(_eventsKey, log);
  }

  /// Call once per app launch. Records today into the local "active days"
  /// set (day-granularity `YYYY-MM-DD` strings) and the first-open day if
  /// not already set. [wasActiveOnDayOffset] then derives D1/D7 retention
  /// from those two facts.
  Future<void> recordAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayString(_now());
    final days = (prefs.getStringList(_activeDaysKey) ?? <String>[]).toSet()..add(today);
    await prefs.setStringList(_activeDaysKey, days.toList());
    await prefs.setString(_firstOpenKey, prefs.getString(_firstOpenKey) ?? today);
    logEvent('app_opened');
  }

  Future<bool> wasActiveOnDayOffset(int offset) async {
    final prefs = await SharedPreferences.getInstance();
    final firstOpen = prefs.getString(_firstOpenKey);
    if (firstOpen == null) return false;
    final target = _dayString(DateTime.parse(firstOpen).add(Duration(days: offset)));
    final days = prefs.getStringList(_activeDaysKey) ?? <String>[];
    return days.contains(target);
  }

  Future<bool> get isDay1Active => wasActiveOnDayOffset(1);
  Future<bool> get isDay7Active => wasActiveOnDayOffset(7);

  String _dayString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
