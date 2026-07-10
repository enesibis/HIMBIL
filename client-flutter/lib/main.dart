import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics/analytics_service.dart';
import 'analytics/http_analytics_sink.dart';
import 'audio/sound_service.dart';
import 'l10n/app_localizations.dart';
import 'net/deep_link_service.dart';
import 'screens/lobby_screen.dart';
import 'screens/splash_screen.dart';
import 'session/guest_account_service.dart';
import 'session/player_session.dart';
import 'theme/palette.dart';
import 'theme/theme_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Crash reporting DSN (madde #51). Supplied at build/run time so no secret
/// is committed — e.g. `flutter run --dart-define=SENTRY_DSN=https://...`.
/// A Sentry project (or Firebase Crashlytics project) has to be created by
/// hand first (external account, can't be automated here); with no DSN
/// configured, this stays a no-op and the app behaves exactly as before.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _runApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.2;
    },
    appRunner: _runApp,
  );
}

Future<void> _runApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PlayerSession.instance.load();
  await GuestAccountService.instance.load();
  await ThemeService.instance.load();
  await SoundService.instance.init();
  // Madde #52: olaylar hem yerel log'a (debug + ring buffer) hem sunucunun
  // analytics ucuna akar; sunucu yoksa HTTP sink sessizce kuyruğunda tutar.
  final httpSink = HttpAnalyticsSink();
  AnalyticsService.instance = AnalyticsService(sink: CompositeSink([const DebugPrintSink(), httpSink]));
  await AnalyticsService.instance.recordAppOpen();
  unawaited(httpSink.flush());
  runApp(const HimbilApp());
}

class HimbilApp extends StatefulWidget {
  const HimbilApp({super.key});

  @override
  State<HimbilApp> createState() => _HimbilAppState();
}

class _HimbilAppState extends State<HimbilApp> {
  StreamSubscription<String>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.getInitialRoomCode().then(_openLobbyForCode);
    _deepLinkSubscription = DeepLinkService.instance.roomCodeStream.listen(_openLobbyForCode);
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  void _openLobbyForCode(String? code) {
    if (code == null) return;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => LobbyScreen(joinCode: code)));
  }

  @override
  Widget build(BuildContext context) {
    // Koyu tema anahtarı (ThemeService) kök MaterialApp'i yeniden kurar:
    // ThemeData'nın parlaklığı değişince Theme'e bağımlı tüm Material
    // bileşenleri yeniden build olur; Palette.x okuyan özel widget'lar da
    // ekranlarının bir sonraki build'inde (Ayarlar'dan dönüşte route
    // geçişi bunu tetikler) yeni paleti alır.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.instance.isDark,
      builder: (context, isDark, _) => _buildApp(isDark),
    );
  }

  Widget _buildApp(bool isDark) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      theme: ThemeData(
        useMaterial3: true,
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: Palette.bgCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.red,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        fontFamily: 'Nunito',
      ),
      // Ekranların çoğu hassas piksel yerleşimli, sabit boyutlu kartlar
      // varsayıyor (bkz. yapılması-gerekenler #30'daki 320-360dp taşma
      // düzeltmesi); sistemin erişilebilirlik font büyütmesi tam aralıkta
      // (3.0x'e kadar) bu yerleşimleri kırar. Kullanıcı tercihini tamamen
      // yok saymak yerine, taşmayı kontrol altında tutan bir üst sınıra
      // kırpıyoruz (madde #57).
      builder: (context, child) {
        final clamped = MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clamped),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
