import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sound_service.dart';
import '../l10n/l10n.dart';
import '../net/room_code.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import 'lobby_screen.dart';

/// "Kod ile Katıl" ekranı — arkadaşının oda koduyla mevcut bir odaya
/// katılma. Gerçek çok oyunculu henüz yok; kod tamamlanınca (ya da demo
/// linkine basılınca) Lobi'ye geçer.
///
/// Oda kodu 6 haneli alfanümerik (`roomCodeAlphabet`), sunucunun gerçek
/// kod formatıyla aynı — bu yüzden görünmez bir [TextField] üzerinden
/// sistem klavyesiyle girdi alınır (36 karakterlik özel bir tuş takımı
/// yerine).
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _JoinScreenState extends State<JoinScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _navigateTimer;
  String _previousText = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.length != _previousText.length) {
      SoundService.instance.playSfx(Sfx.buttonTap);
    }
    _previousText = text;
    setState(() {});
    if (text.length == roomCodeLength) {
      _goToLobbySoon(text);
    } else {
      _navigateTimer?.cancel();
    }
  }

  void _fillDemoCode() {
    SoundService.instance.playSfx(Sfx.buttonTap);
    const demo = 'K7X29M';
    _controller.value = const TextEditingValue(
      text: demo,
      selection: TextSelection.collapsed(offset: demo.length),
    );
  }

  void _goToLobbySoon(String code) {
    _navigateTimer?.cancel();
    _navigateTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _controller.text.length != roomCodeLength) return;
      _focusNode.unfocus();
      SoundService.instance.playSfx(Sfx.lobbyJoinSuccess);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => LobbyScreen(joinCode: code)),
      );
    });
  }

  void _goBack() {
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        body: CarnivalBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  CircleBackButton(onTap: _goBack),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.joinTitle,
                    style: AppText.baloo(size: 21, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.joinSubtitle,
                    style: AppText.nunito(
                      size: 13,
                      weight: FontWeight.w700,
                      color: Palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < roomCodeLength; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              _codeBox(
                                i < _controller.text.length
                                    ? _controller.text[i]
                                    : '',
                                focused: i == _controller.text.length,
                              ),
                            ],
                          ],
                        ),
                        Opacity(
                          opacity: 0,
                          child: SizedBox(
                            width: 1,
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              showCursor: false,
                              textCapitalization: TextCapitalization.characters,
                              keyboardType: TextInputType.text,
                              maxLength: roomCodeLength,
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp('[a-zA-Z0-9]'),
                                ),
                                _UpperCaseTextFormatter(),
                                LengthLimitingTextInputFormatter(
                                  roomCodeLength,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: _fillDemoCode,
                      child: Text(
                        context.l10n.joinDemoFill,
                        style: AppText.nunito(
                          size: 12,
                          weight: FontWeight.w800,
                          color: Palette.blue,
                        ).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeBox(String value, {required bool focused}) {
    return Container(
      width: 42,
      height: 54,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          bottom: BorderSide(
            color: focused ? Palette.red : Palette.red.withValues(alpha: 0.35),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Palette.textPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: AppText.baloo(size: 20, weight: FontWeight.w800),
      ),
    );
  }
}
