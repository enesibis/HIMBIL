import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/palette.dart';

void main() {
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
      home: const HomeScreen(),
    );
  }
}
