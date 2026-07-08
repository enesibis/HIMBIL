/// Server address, resolved at build/run time via `--dart-define`, per
/// docs/himbil-proje-kilavuzu.md §10 ("client'a --dart-define ile dev/prod
/// sunucu adresi"). Defaults point at a local dev server
/// (`npm run dev` in `server/`) so `flutter run` works out of the box
/// without any flags during Stage 3 development.
///
/// Example: `flutter run --dart-define=HIMBIL_SERVER_HOST=192.168.1.10`
class NetConfig {
  static const String serverHost = String.fromEnvironment('HIMBIL_SERVER_HOST', defaultValue: 'localhost');
  static const int serverPort = int.fromEnvironment('HIMBIL_SERVER_PORT', defaultValue: 2567);
  static const bool useTls = bool.fromEnvironment('HIMBIL_SERVER_TLS');

  static String get _httpScheme => useTls ? 'https' : 'http';
  static String get _wsScheme => useTls ? 'wss' : 'ws';

  static String get httpBaseUrl => '$_httpScheme://$serverHost:$serverPort';

  static Uri wsUri(String processId, String roomId, String sessionId, {String? reconnectionToken}) {
    final query = <String, String>{
      'sessionId': sessionId,
      'reconnectionToken': ?reconnectionToken,
    };
    return Uri(
      scheme: _wsScheme,
      host: serverHost,
      port: serverPort,
      pathSegments: [processId, roomId],
      queryParameters: query,
    );
  }
}
