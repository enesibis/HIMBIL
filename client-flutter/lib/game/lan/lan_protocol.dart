import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Sunucusuz LAN modu (madde #10) için minimal, bağımsız tel protokolü.
/// `client-flutter/lib/net/`'teki Colyseus istemcisi (msgpack + Colyseus'a
/// özgü join/roomData çerçeveleme) burada yeniden kullanılamaz — LAN'da ne
/// bir HTTP matchmake adımı ne de Colyseus oturum semantiği var. Bunun yerine
/// düz JSON, 4 byte'lık big-endian uzunluk-öneki ile [Socket] üzerinde
/// çerçevelenir. Mesaj sözlüğü (chooseCard/slamPress/state/slamPressResult/
/// roundScored) kasıtlı olarak server/schema/messages.ts ile aynı isimlerle
/// tutuldu — iki port arasında zihinsel eşleme kolaylaşsın diye.
class LanFraming {
  LanFraming._();

  static const int lengthPrefixBytes = 4;

  /// Bir mesajı `[4-byte length][utf8 json]` olarak kodlar.
  static Uint8List encode(Map<String, Object?> message) {
    final payload = utf8.encode(jsonEncode(message));
    final buffer = BytesBuilder();
    final lengthBytes = ByteData(lengthPrefixBytes)..setUint32(0, payload.length, Endian.big);
    buffer.add(lengthBytes.buffer.asUint8List());
    buffer.add(payload);
    return buffer.toBytes();
  }
}

/// Gelen byte akışını (bir [Socket]'ten) uzunluk-önekine göre mesajlara
/// ayıran, TCP'nin parçalayıp birleştirebileceği veriyi doğru şekilde
/// yeniden birleştiren tampon. `add()` ile beslenir, tamamlanan her mesaj
/// [messages] stream'inde bir `Map` olarak çıkar.
class LanFrameDecoder {
  final _buffer = BytesBuilder();
  final _controller = StreamController<Map<String, Object?>>.broadcast();

  Stream<Map<String, Object?>> get messages => _controller.stream;

  void add(List<int> chunk) {
    _buffer.add(chunk);
    _drain();
  }

  void _drain() {
    while (true) {
      final bytes = _buffer.toBytes();
      if (bytes.length < LanFraming.lengthPrefixBytes) return;
      final length = ByteData.sublistView(bytes, 0, LanFraming.lengthPrefixBytes).getUint32(0, Endian.big);
      final totalNeeded = LanFraming.lengthPrefixBytes + length;
      if (bytes.length < totalNeeded) return;

      final payload = bytes.sublist(LanFraming.lengthPrefixBytes, totalNeeded);
      _buffer.clear();
      if (bytes.length > totalNeeded) _buffer.add(bytes.sublist(totalNeeded));

      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is Map) _controller.add(decoded.cast<String, Object?>());
    }
  }

  Future<void> close() => _controller.close();
}

/// Bir [Socket] üzerinden [LanFraming]/[LanFrameDecoder] ile JSON mesaj
/// alışverişi yapan ince sarmalayıcı — host tarafında her bağlanan misafir
/// için, misafir tarafında host bağlantısı için kullanılır.
class LanSocketChannel {
  LanSocketChannel(this.socket) {
    socket.listen(
      _decoder.add,
      onDone: () => _decoder.close(),
      onError: (Object _) => _decoder.close(),
      cancelOnError: true,
    );
  }

  final Socket socket;
  final _decoder = LanFrameDecoder();

  Stream<Map<String, Object?>> get messages => _decoder.messages;

  void send(Map<String, Object?> message) {
    try {
      socket.add(LanFraming.encode(message));
    } catch (_) {
      // Soket kapanmışsa yazma başarısız olabilir — çağıran taraf zaten
      // bağlantı kopuşunu ayrıca (onDone/onError) öğrenecek.
    }
  }

  Future<void> close() async {
    await _decoder.close();
    await socket.close();
  }
}
