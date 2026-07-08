import 'package:flutter/material.dart';

import '../net/himbil_net_client.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';

/// "Bağlantı koptu" göstergesi (madde #59) — [HimbilNetClient.connectionState]'i
/// dinleyip yeniden bağlanma denemesi sürerken ekranın üstünde küçük bir şerit
/// gösterir; `connected` durumunda hiçbir şey render etmez. Not yet wired
/// into a screen — `GameController`'ın yerel/bot-driven varsayılan modu
/// [HimbilNetClient] kullanmıyor (bkz. `himbil_net_client.dart`'ın doc
/// yorumu); bu widget, o entegrasyon yapıldığında kullanılacak hazır parça.
class ConnectionStatusBanner extends StatelessWidget {
  final Stream<NetConnectionState> connectionState;

  const ConnectionStatusBanner({super.key, required this.connectionState});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetConnectionState>(
      stream: connectionState,
      initialData: NetConnectionState.connected,
      builder: (context, snapshot) {
        final state = snapshot.data ?? NetConnectionState.connected;
        if (state == NetConnectionState.connected) return const SizedBox.shrink();

        final isBusy = state == NetConnectionState.reconnecting || state == NetConnectionState.connecting;
        final message = switch (state) {
          NetConnectionState.reconnecting => 'Bağlantı koptu, yeniden bağlanılıyor…',
          NetConnectionState.connecting => 'Bağlanılıyor…',
          NetConnectionState.disconnected => 'Bağlantı kesildi',
          NetConnectionState.connected => '',
        };
        final color = state == NetConnectionState.disconnected ? Palette.red : Palette.mustard;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: color,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
