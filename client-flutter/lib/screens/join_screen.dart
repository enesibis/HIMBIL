import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import 'lobby_screen.dart';

/// "Kod ile Katıl" ekranı — arkadaşının oda koduyla mevcut bir odaya
/// katılma. Gerçek çok oyunculu henüz yok; 5. hane girilince (ya da
/// demo linkine basılınca) Lobi'ye geçer.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final List<String> _digits = List.filled(5, '');
  int _cursor = 0;
  Timer? _navigateTimer;

  void _pressDigit(String d) {
    if (_cursor >= 5) return;
    setState(() {
      _digits[_cursor] = d;
      _cursor++;
    });
    if (_cursor == 5) _goToLobbySoon();
  }

  void _backspace() {
    if (_cursor == 0) return;
    _navigateTimer?.cancel();
    setState(() {
      _cursor--;
      _digits[_cursor] = '';
    });
  }

  void _fillDemoCode() {
    setState(() {
      const demo = ['3', '4', '5', '2', '1'];
      for (var i = 0; i < 5; i++) {
        _digits[i] = demo[i];
      }
      _cursor = 5;
    });
    _goToLobbySoon();
  }

  void _goToLobbySoon() {
    _navigateTimer?.cancel();
    _navigateTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _cursor != 5) return;
      final code = _digits.join();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LobbyScreen(joinCode: code)));
    });
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                CircleBackButton(onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 14),
                Text('Kod ile Katıl', style: AppText.baloo(size: 21, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Arkadaşının oda kodunu gir', style: AppText.nunito(size: 13, weight: FontWeight.w700, color: Palette.textSecondary)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _codeBox(_digits[i]),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _fillDemoCode,
                    child: Text(
                      'Örnek kod ile doldur (34521)',
                      style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Palette.blue).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const Spacer(),
                _keypad(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeBox(String value) {
    return Container(
      width: 46,
      height: 58,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: const Border(bottom: BorderSide(color: Palette.red, width: 4)),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      alignment: Alignment.center,
      child: Text(value, style: AppText.baloo(size: 22, weight: FontWeight.w800)),
    );
  }

  Widget _keypad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'BACKSPACE'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final key in row) ...[
                  if (key != row.first) const SizedBox(width: 10),
                  Expanded(child: _keypadButton(key)),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _keypadButton(String key) {
    if (key.isEmpty) return const SizedBox(height: 52);
    final isBackspace = key == 'BACKSPACE';
    return GestureDetector(
      onTap: () {
        if (isBackspace) {
          _backspace();
        } else {
          _pressDigit(key);
        }
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: isBackspace
            ? const Icon(Icons.backspace_outlined, size: 18, color: Palette.textPrimary)
            : Text(key, style: AppText.baloo(size: 19, weight: FontWeight.w700)),
      ),
    );
  }
}
