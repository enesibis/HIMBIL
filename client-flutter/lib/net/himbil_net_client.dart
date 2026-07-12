import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'colyseus_protocol.dart';
import 'net_config.dart';

class HimbilNetException implements Exception {
  HimbilNetException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum NetConnectionState { disconnected, connecting, connected, reconnecting }

/// Talks to the Stage 3 Colyseus room (`server/rooms/HimbilRoom.ts`) over a
/// hand-rolled subset of Colyseus's wire protocol — see
/// `colyseus_protocol.dart` and `server/schema/messages.ts` for why there's
/// no official client SDK to depend on here.
///
/// This class only connects and exchanges messages; it does not replace
/// `GameController`'s local bot-driven state (that remains the default,
/// fully offline game mode). Wiring a screen to consume `stateUpdates`
/// instead of local simulation is a separate, later integration step.
class HimbilNetClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  String? _roomId;
  String? _reconnectionToken;
  bool _joined = false;

  /// Set only by [disconnect] (the player chose "< Menü"). Distinguishes a
  /// deliberate leave from an unexpected drop in [_onDone], since only the
  /// latter should trigger auto-reconnect — mirrors the server's
  /// `onLeave`/`onDrop` split in `HimbilRoom.ts` (madde #59).
  bool _consentedDisconnect = false;
  int _autoReconnectAttempts = 0;
  Timer? _autoReconnectTimer;

  /// Bounded to stay within the server's 30s reconnection grace window
  /// (`RECONNECT_GRACE_SECONDS` in `HimbilRoom.ts`) — 7 attempts at 4s
  /// apart is ~28s, then this client gives up in lockstep with the server.
  static const _maxAutoReconnectAttempts = 7;
  static const _autoReconnectInterval = Duration(seconds: 4);

  final _stateController = StreamController<Map<String, Object?>>.broadcast();
  final _slamResultController = StreamController<Map<String, Object?>>.broadcast();
  final _roundScoredController = StreamController<Map<String, Object?>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<NetConnectionState>.broadcast();

  /// Filtered `RoomStateView` payloads (see server/schema/messages.ts), decoded from msgpack maps.
  Stream<Map<String, Object?>> get stateUpdates => _stateController.stream;
  Stream<Map<String, Object?>> get slamResults => _slamResultController.stream;

  /// `RoundScoredMessage` payloads — the only place the finished round's
  /// press ranking is available (room state clears `slamOrder` when the
  /// window closes); drives the slam-celebration screen.
  Stream<Map<String, Object?>> get roundScoredEvents => _roundScoredController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<NetConnectionState> get connectionState => _connectionController.stream;

  String? get roomId => _roomId;
  bool get isJoined => _joined;

  // guestId/guestToken: odaya doğrulanmış misafir-hesap bağı kurar — maç
  // sonu ödülleri sunucu defterine yazılır (bkz. HimbilRoom.linkGuestAccount).
  // Verilmezse (ya da doğrulanamazsa) maç aynen oynanır, yalnız defter
  // kaydı atlanır.
  Future<void> createRoom({String? name, String? guestId, String? guestToken}) =>
      _matchmake('create', {'name': ?name, 'guestId': ?guestId, 'guestToken': ?guestToken});

  Future<void> quickPlay({String? name, String? guestId, String? guestToken}) =>
      _matchmake('joinOrCreate', {'name': ?name, 'guestId': ?guestId, 'guestToken': ?guestToken});

  /// Joins a specific room by its human-readable code. Fails (rather than
  /// silently starting a new room) if no room with that code is open — see
  /// `HimbilRoom`'s `.filterBy(["roomCode"])` registration.
  Future<void> joinByCode(String roomCode, {String? name, String? guestId, String? guestToken}) =>
      _matchmake('join', {'roomCode': roomCode, 'name': ?name, 'guestId': ?guestId, 'guestToken': ?guestToken});

  Future<void> _matchmake(String method, Map<String, Object?> options) async {
    _consentedDisconnect = false;
    _autoReconnectAttempts = 0;
    _autoReconnectTimer?.cancel();
    _connectionController.add(NetConnectionState.connecting);
    final uri = Uri.parse('${NetConfig.httpBaseUrl}/matchmake/$method/himbil');

    final http.Response response;
    try {
      response = await http.post(uri, headers: const {'content-type': 'application/json'}, body: jsonEncode(options));
    } catch (e) {
      _connectionController.add(NetConnectionState.disconnected);
      throw HimbilNetException('Sunucuya ulaşılamadı: $e');
    }

    if (response.statusCode >= 400) {
      _connectionController.add(NetConnectionState.disconnected);
      throw HimbilNetException(_extractErrorMessage(response.body));
    }

    final data = jsonDecode(response.body) as Map<String, Object?>;
    _roomId = data['roomId'] as String;
    await _openSocket(
      processId: data['processId'] as String,
      roomId: _roomId!,
      sessionId: data['sessionId'] as String,
    );
  }

  /// Resumes a previous session using the reconnection token handed out by
  /// the initial join. Must be called with the same `HimbilNetClient`
  /// instance that performed the original join (it holds the roomId/token).
  Future<void> reconnect() async {
    final roomId = _roomId;
    final token = _reconnectionToken;
    if (roomId == null || token == null) {
      throw HimbilNetException('Yeniden bağlanılacak önceki bir oturum yok.');
    }

    _connectionController.add(NetConnectionState.reconnecting);
    final uri = Uri.parse('${NetConfig.httpBaseUrl}/matchmake/reconnect/$roomId');

    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'reconnectionToken': token}),
      );
    } catch (e) {
      _connectionController.add(NetConnectionState.disconnected);
      throw HimbilNetException('Sunucuya ulaşılamadı: $e');
    }

    if (response.statusCode >= 400) {
      _connectionController.add(NetConnectionState.disconnected);
      throw HimbilNetException(_extractErrorMessage(response.body));
    }

    final data = jsonDecode(response.body) as Map<String, Object?>;
    await _openSocket(
      processId: data['processId'] as String,
      roomId: roomId,
      sessionId: data['sessionId'] as String,
    );
  }

  Future<void> _openSocket({required String processId, required String roomId, required String sessionId}) async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _joined = false;

    final uri = NetConfig.wsUri(processId, roomId, sessionId, reconnectionToken: _reconnectionToken);
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _subscription = channel.stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void _onData(dynamic data) {
    final bytes = data is Uint8List ? data : Uint8List.fromList(List<int>.from(data as List<dynamic>));
    final frame = decodeColyseusFrame(bytes);

    switch (frame) {
      case JoinRoomFrame():
        _reconnectionToken = frame.reconnectionToken;
        _joined = true;
        _connectionController.add(NetConnectionState.connected);
        _channel?.sink.add(encodeJoinRoomAck());

      case RoomDataFrame():
        final payload = frame.payload;
        if (frame.type == 'state' && payload is Map) {
          _stateController.add(payload.cast<String, Object?>());
        } else if (frame.type == 'slamPressResult' && payload is Map) {
          _slamResultController.add(payload.cast<String, Object?>());
        } else if (frame.type == 'roundScored' && payload is Map) {
          _roundScoredController.add(payload.cast<String, Object?>());
        }

      case ErrorFrame():
        _errorController.add(frame.message);

      case LeaveRoomFrame():
      case PingFrame():
      case UnknownFrame():
        break;
    }
  }

  void _onError(Object error) {
    _errorController.add('$error');
  }

  void _onDone() {
    _joined = false;
    if (_consentedDisconnect || _roomId == null || _reconnectionToken == null) {
      _connectionController.add(NetConnectionState.disconnected);
      return;
    }
    _connectionController.add(NetConnectionState.reconnecting);
    _scheduleAutoReconnectAttempt();
  }

  void _scheduleAutoReconnectAttempt() {
    _autoReconnectTimer?.cancel();
    final delay = _autoReconnectAttempts == 0 ? Duration.zero : _autoReconnectInterval;
    _autoReconnectTimer = Timer(delay, () async {
      _autoReconnectAttempts++;
      try {
        await reconnect();
      } catch (_) {
        if (_consentedDisconnect) return;
        if (_autoReconnectAttempts >= _maxAutoReconnectAttempts) {
          _connectionController.add(NetConnectionState.disconnected);
        } else {
          _scheduleAutoReconnectAttempt();
        }
      }
    });
  }

  void chooseCard(int? cardId) => _send('chooseCard', {'cardId': cardId});

  void confirmChoice() => _send('confirmChoice');

  void pressSlam() => _send('slamPress');

  void _send(String type, [Object? payload]) {
    final channel = _channel;
    if (channel == null || !_joined) return;
    channel.sink.add(encodeRoomData(type, payload));
  }

  Future<void> disconnect() async {
    _consentedDisconnect = true;
    _autoReconnectTimer?.cancel();
    await _subscription?.cancel();
    // Close code 4000 is Colyseus's `CloseCode.CONSENTED` — without it the
    // server can't tell a deliberate "< Menü" leave from a dropped
    // connection, and would waste a 30s reconnection grace slot on a
    // player who isn't coming back (see `HimbilRoom.onLeave` vs `onDrop`).
    await _channel?.sink.close(4000);
    _channel = null;
    _joined = false;
    // dispose() bu metodu beklemeden controller'ları kapatır; kapanmış bir
    // stream'e add() StreamError fırlatır (lobi fallback yolunda gerçek senaryo).
    if (!_connectionController.isClosed) {
      _connectionController.add(NetConnectionState.disconnected);
    }
  }

  /// Closes the socket without the consented close code, so the server
  /// treats it exactly like a real network drop (`onDrop`, not `onLeave`).
  /// Test-only seam for exercising the auto-reconnect path end-to-end
  /// against a real server — there's no other way to simulate "the OS
  /// killed the connection" from Dart.
  @visibleForTesting
  Future<void> debugSimulateUnexpectedDrop() async {
    await _channel?.sink.close();
  }

  void dispose() {
    _autoReconnectTimer?.cancel();
    unawaited(disconnect());
    _stateController.close();
    _slamResultController.close();
    _roundScoredController.close();
    _errorController.close();
    _connectionController.close();
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) return decoded['error'] as String;
    } catch (_) {
      // fall through to generic message below
    }
    return 'İstek başarısız oldu.';
  }
}
