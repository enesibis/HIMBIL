import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/splash_screen.dart';
import 'session/player_session.dart';
import 'theme/palette.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await PlayerSession.load();
  runApp(const HimbilApp());
}

class HimbilApp extends StatelessWidget {
  const HimbilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hımbıl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.bgCream,
        colorScheme: ColorScheme.fromSeed(seedColor: Palette.red, brightness: Brightness.light),
        fontFamily: 'Nunito',
      ),
      home: const SplashScreen(),
    );
  }
}
