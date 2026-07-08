import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../session/player_session.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import '../widgets/gradient_cta.dart';
import 'onboarding/age_step.dart';
import 'onboarding/avatar_step.dart';

/// Profil düzenleme (madde #54): onboarding sonrası isim/yaş/karakter/renk
/// hiç değiştirilemiyordu (yalnız çerçeve Mağaza'dan değişiyordu). Aynı
/// onboarding adım widget'larını ([AgeStep], [AvatarStep]) burada yeniden
/// kullanıyoruz; isim için onboarding'in tam-sayfa ortalanmış [NameStep]'i
/// yerine burada daha kompakt, bölüm başlıklı bir alan var.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nameController = TextEditingController(text: PlayerSession.instance.name);
  late int _age = PlayerSession.instance.age;
  late int _characterIndex = PlayerSession.instance.avatarCharacterIndex;
  late int _colorIndex = PlayerSession.instance.avatarColorIndex;
  late String _frame = PlayerSession.instance.avatarFrame;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _initial => _nameController.text.isNotEmpty ? _nameController.text.substring(0, 1).toUpperCase() : '?';

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    await PlayerSession.instance.updateProfile(
      name: name,
      age: _age,
      avatarCharacterIndex: _characterIndex,
      avatarColorIndex: _colorIndex,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width - 44;
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
                Text(l10n.profileEditTitle, style: AppText.baloo(size: 21, weight: FontWeight.w700)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(l10n.profileEditNameLabel),
                        const SizedBox(height: 8),
                        _nameField(),
                        const SizedBox(height: 26),
                        AgeStep(age: _age, onChanged: (value) => setState(() => _age = value)),
                        const SizedBox(height: 10),
                        AvatarStep(
                          initial: _initial,
                          characterIndex: _characterIndex,
                          colorIndex: _colorIndex,
                          frame: _frame,
                          onCharacterSelected: (i) => setState(() => _characterIndex = i),
                          onColorSelected: (i) => setState(() => _colorIndex = i),
                          onFrameSelected: (f) => setState(() => _frame = f),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  child: GradientCta(
                    title: _saving ? l10n.profileEditSaving : l10n.profileEditSave,
                    width: width,
                    height: 64,
                    color: Palette.redLight,
                    shadowBarColor: Palette.redShadow,
                    borderRadius: 22,
                    titleSize: 17,
                    onTap: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary).copyWith(letterSpacing: 1));
  }

  Widget _nameField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        maxLength: 16,
        style: AppText.baloo(size: 16, weight: FontWeight.w700),
        cursorColor: Palette.red,
        decoration: const InputDecoration(counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 14)),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
