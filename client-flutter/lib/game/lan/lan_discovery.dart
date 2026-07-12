import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// LAN modu (madde #10) sabit portları. Discovery UDP broadcast, maç TCP
/// üzerinden oynanır — ikisi ayrı soket, ayrı port. `dart:io`'nun kendi
/// `RawDatagramSocket`/`ServerSocket`'i yeterli olduğu için (bkz. plan
/// dosyasındaki fizibilite araştırması) yeni bir pub bağımlılığı gerekmedi.
class LanPorts {
  LanPorts._();
  static const int discoveryUdpPort = 45227;
  static const int matchTcpPort = 45228;
}

/// Bir host odasının keşif duyurusu.
class LanHostAdvertisement {
  final String roomName;
  final String hostName;
  final InternetAddress address;
  final int tcpPort;

  const LanHostAdvertisement({
    required this.roomName,
    required this.hostName,
    required this.address,
    required this.tcpPort,
  });
}

const _discoverMessageType = 'HIMBIL_DISCOVER';
const _hostMessageType = 'HIMBIL_HOST';

/// Host tarafı: [LanPorts.discoveryUdpPort]'ta dinler, bir `HIMBIL_DISCOVER`
/// paketine kendi oda bilgisiyle unicast yanıt verir. `bind` başarısız
/// olabilir (ör. port zaten kullanımda) — çağıran taraf hatayı yakalayıp
/// kullanıcıya göstermeli.
class LanHostAdvertiser {
  RawDatagramSocket? _socket;

  Future<void> start({required String roomName, required String hostName}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, LanPorts.discoveryUdpPort);
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      Map<String, Object?>? message;
      try {
        message = (jsonDecode(utf8.decode(datagram.data)) as Map).cast<String, Object?>();
      } catch (_) {
        return;
      }
      if (message['type'] != _discoverMessageType) return;

      final reply = utf8.encode(jsonEncode({
        'type': _hostMessageType,
        'roomName': roomName,
        'hostName': hostName,
        'tcpPort': LanPorts.matchTcpPort,
      }));
      socket.send(reply, datagram.address, datagram.port);
    });
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}

/// Katılan taraf: subnet broadcast adresine periyodik `HIMBIL_DISCOVER`
/// gönderir, gelen `HIMBIL_HOST` yanıtlarını (adrese göre tekilleştirilmiş)
/// bir stream olarak sunar. `start()` çağrıldıktan sonra [hosts] dinlenmeli;
/// `stop()` taramayı durdurur.
class LanHostScanner {
  RawDatagramSocket? _socket;
  Timer? _pingTimer;
  final _controller = StreamController<LanHostAdvertisement>.broadcast();

  Stream<LanHostAdvertisement> get hosts => _controller.stream;

  Future<void> start() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    _socket = socket;
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      Map<String, Object?>? message;
      try {
        message = (jsonDecode(utf8.decode(datagram.data)) as Map).cast<String, Object?>();
      } catch (_) {
        return;
      }
      if (message['type'] != _hostMessageType) return;

      _controller.add(LanHostAdvertisement(
        roomName: message['roomName'] as String? ?? '...',
        hostName: message['hostName'] as String? ?? '...',
        address: datagram.address,
        tcpPort: (message['tcpPort'] as num?)?.toInt() ?? LanPorts.matchTcpPort,
      ));
    });

    _ping();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _ping());
  }

  void _ping() {
    final socket = _socket;
    if (socket == null) return;
    final payload = utf8.encode(jsonEncode({'type': _discoverMessageType}));
    // 255.255.255.255 (limited broadcast) alt ağ maskesini bilmeye gerek
    // bırakmaz — çoğu router/AP'de yerel segmentte çalışır. Misafir izole
    // (client isolation) bir Wi-Fi ağındaysa hiçbir soket/izin bunu aşamaz;
    // bu bir kod sınırlaması değil, ağ ortamı riskidir.
    socket.send(payload, InternetAddress('255.255.255.255'), LanPorts.discoveryUdpPort);
  }

  void stop() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _socket?.close();
    _socket = null;
  }
}
