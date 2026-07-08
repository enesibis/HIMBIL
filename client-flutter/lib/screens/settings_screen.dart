import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/circle_back_button.dart';
import 'privacy_policy_screen.dart';

/// Ayarlar ekranı (madde #53): ses/müzik anahtarları + dil + gizlilik
/// politikası linki (store zorunluluğu).
///
/// Bu ekran ve [ProfileEditScreen] madde #56'nın i18n altyapısını
/// (`flutter_localizations` + ARB, bkz. `lib/l10n/app_tr.arb`) gerçekten
/// kullanan ilk iki ekran — geri kalan ekranlardaki düzinelerce hardcoded
/// TR metnini aynı ana taşımak ayrı, büyük bir mekanik iş (bkz.
/// docs/yapılması-gerekenler.md #56); burada altyapının uçtan uca
/// çalıştığını göstermek amaçlanıyor, tüm metinleri taşımak değil.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _sfxEnabled = SoundService.instance.sfxEnabled;
  late bool _musicEnabled = SoundService.instance.musicEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                Text(l10n.settingsTitle, style: AppText.baloo(size: 21, weight: FontWeight.w700)),
                const SizedBox(height: 20),
                _sectionCard([
                  _switchRow(
                    icon: Icons.volume_up_rounded,
                    label: l10n.settingsSfx,
                    value: _sfxEnabled,
                    onChanged: (value) {
                      setState(() => _sfxEnabled = value);
                      SoundService.instance.setSfxEnabled(value);
                    },
                  ),
                  _divider(),
                  _switchRow(
                    icon: Icons.music_note_rounded,
                    label: l10n.settingsMusic,
                    value: _musicEnabled,
                    onChanged: (value) {
                      setState(() => _musicEnabled = value);
                      SoundService.instance.setMusicEnabled(value);
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _sectionCard([
                  _infoRow(icon: Icons.language_rounded, label: l10n.settingsLanguage, trailing: l10n.settingsLanguageValue),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      l10n.settingsLanguageComingSoon,
                      style: AppText.nunito(size: 11, weight: FontWeight.w700, color: Palette.textSecondary),
                    ),
                  ),
                  _divider(),
                  _linkRow(
                    icon: Icons.privacy_tip_rounded,
                    label: l10n.settingsPrivacyPolicy,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: Palette.textPrimary.withValues(alpha: 0.06));

  Widget _switchRow({required IconData icon, required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.nunito(size: 14, weight: FontWeight.w700))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: Palette.red),
        ],
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String label, required String trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Palette.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.nunito(size: 14, weight: FontWeight.w700))),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkRow({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppText.nunito(size: 14, weight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
