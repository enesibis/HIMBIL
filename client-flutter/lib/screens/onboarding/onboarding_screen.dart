import 'package:flutter/material.dart';

import '../../session/player_session.dart';
import '../../theme/palette.dart';
import '../../widgets/carnival_background.dart';
import '../../widgets/gradient_cta.dart';
import '../home_screen.dart';
import 'age_step.dart';
import 'avatar_step.dart';
import 'complete_step.dart';
import 'name_step.dart';
import 'welcome_step.dart';

/// İlk açılışta gösterilen, tasarım referansında bulunmayan onboarding
/// akışı: Hoş Geldin → İsim → Yaş → Avatar Oluştur → Tamamlandı.
/// Her adım tek bir PageView içinde parallax geçişle akar; devam butonu
/// bu ekran tarafından yönetilir çünkü doğrulama (örn. isim boş olamaz)
/// adımlar arası ortak durum gerektirir.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 5;
  static const _buttonLabels = ['Haydi Başlayalım', 'Devam Et', 'Devam Et', 'Devam Et', 'Oyuna Başla'];

  final _pageController = PageController();
  late final TextEditingController _nameController;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: PlayerSession.name == 'Sen' ? '' : PlayerSession.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _canContinue => _step != 1 || _nameController.text.trim().isNotEmpty;

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _next() {
    if (!_canContinue) return;
    if (_step == 1) PlayerSession.name = _nameController.text.trim();
    if (_step == _totalSteps - 1) {
      _finish();
      return;
    }
    _goTo(_step + 1);
  }

  void _back() {
    if (_step == 0) return;
    _goTo(_step - 1);
  }

  Future<void> _finish() async {
    await PlayerSession.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _step == 0 ? const SizedBox(width: 36) : _backButton(),
                    Expanded(child: _progressDots()),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _parallaxPage(0, const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: WelcomeStep())),
                    _parallaxPage(
                      1,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: NameStep(controller: _nameController, onSubmitted: _next),
                      ),
                    ),
                    _parallaxPage(
                      2,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: AgeStep(age: PlayerSession.age, onChanged: (v) => setState(() => PlayerSession.age = v)),
                      ),
                    ),
                    _parallaxPage(
                      3,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: AvatarStep(
                          initial: PlayerSession.initial,
                          characterIndex: PlayerSession.avatarCharacterIndex,
                          colorIndex: PlayerSession.avatarColorIndex,
                          frame: PlayerSession.avatarFrame,
                          onCharacterSelected: (i) => setState(() => PlayerSession.avatarCharacterIndex = i),
                          onColorSelected: (i) => setState(() => PlayerSession.avatarColorIndex = i),
                          onFrameSelected: (f) => setState(() => PlayerSession.avatarFrame = f),
                        ),
                      ),
                    ),
                    _parallaxPage(
                      4,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: CompleteStep(
                          name: _nameController.text.trim().isEmpty ? PlayerSession.name : _nameController.text.trim(),
                          initial: PlayerSession.initial,
                          characterIndex: PlayerSession.avatarCharacterIndex,
                          colorIndex: PlayerSession.avatarColorIndex,
                          frame: PlayerSession.avatarFrame,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 22),
                child: Opacity(
                  opacity: _canContinue ? 1.0 : 0.45,
                  child: GradientCta(
                    title: _buttonLabels[_step].toUpperCase(),
                    width: MediaQuery.sizeOf(context).width - 56,
                    height: 68,
                    color: Palette.redLight,
                    shadowBarColor: Palette.redShadow,
                    borderRadius: 24,
                    titleSize: 16,
                    onTap: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _parallaxPage(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, c) {
        double page = index.toDouble();
        if (_pageController.hasClients && _pageController.position.haveDimensions) {
          page = _pageController.page ?? _step.toDouble();
        } else {
          page = _step.toDouble();
        }
        final delta = (page - index).clamp(-1.0, 1.0);
        final scale = 1 - delta.abs() * 0.12;
        final opacity = 1 - delta.abs();
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: c),
        );
      },
      child: Center(child: child),
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: _back,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Palette.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, size: 18, color: Palette.textPrimary),
      ),
    );
  }

  Widget _progressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _totalSteps; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            width: i == _step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= _step ? Palette.red : Palette.textPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ],
    );
  }
}
