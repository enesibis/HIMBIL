import 'package:flutter/material.dart';

import '../audio/sound_service.dart';
import '../l10n/l10n.dart';
import '../theme/palette.dart';
import '../theme/text_styles.dart';
import '../widgets/carnival_background.dart';
import '../widgets/gradient_cta.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/store_tab.dart';
import '../widgets/user_avatar.dart';
import '../session/player_session.dart';
import 'join_screen.dart';
import 'lobby_screen.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class _ProfileStat {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> badgeGradient;

  const _ProfileStat({required this.value, required this.label, required this.icon, required this.badgeGradient});
}

/// Ana Menü — tasarımdaki Home ekranı: sabit header + "Oyna"/"Mağaza"/"Profil"
/// sekmeleri arasında geçiş yapan alt pill-bar. "Oyna" sekmesinde Hızlı
/// Oyna / Oda Kur / Kodla Katıl; "Mağaza" sekmesinde kart sırtı ve çerçeve
/// satın alma; "Profil" sekmesinde istatistik grid'i + liderlik tablosu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    SoundService.instance.playMusic(MusicTrack.menuLoop);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CarnivalBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
                child: _header(),
              ),
              Expanded(
                child: switch (_tabIndex) {
                  0 => _playTab(context),
                  1 => const StoreTab(),
                  _ => _profileTab(),
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: HomeBottomNav(currentIndex: _tabIndex, onChanged: (i) => setState(() => _tabIndex = i)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                boxShadow: [BoxShadow(color: Palette.red.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/images/himbil_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(width: 9),
            Text(context.l10n.appTitle, style: AppText.baloo(size: 23, weight: FontWeight.w800)),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                SoundService.instance.playSfx(Sfx.buttonTap);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: Icon(Icons.settings_rounded, size: 19, color: Palette.textSecondary),
              ),
            ),
            const SizedBox(width: 10),
            UserAvatar(
              size: 40,
              imagePath: PlayerSession.instance.avatarCharacter.imagePath,
              initial: PlayerSession.instance.initial,
              gradient: PlayerSession.instance.avatarColor.gradient,
              frame: PlayerSession.instance.avatarFrame,
            ),
          ],
        ),
      ],
    );
  }

  Widget _playTab(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 44;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(context.l10n.homeGreeting, style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary)),
          const SizedBox(height: 2),
          Text(context.l10n.homeTagline, style: AppText.baloo(size: 23, weight: FontWeight.w700)),
          const SizedBox(height: 20),
          GradientCta(
            title: context.l10n.homeQuickPlay,
            subtitle: context.l10n.homeQuickPlaySubtitle,
            width: width,
            height: 96,
            color: Palette.redLight,
            shadowBarColor: Palette.redShadow,
            borderRadius: 28,
            titleSize: 20,
            onTap: () => _goToQuickPlay(context),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Palette.textPrimary.withValues(alpha: 0.1), thickness: 2)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(context.l10n.homeOrPrivateRoom, style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
              ),
              Expanded(child: Divider(color: Palette.textPrimary.withValues(alpha: 0.1), thickness: 2)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _secondaryCard(
                  label: context.l10n.homeCreateRoom,
                  icon: Icons.add_rounded,
                  iconColor: Palette.mustard,
                  onTap: () => _goToCreateRoom(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _secondaryCard(
                  label: context.l10n.homeJoinWithCode,
                  icon: Icons.key_rounded,
                  iconColor: Palette.blue,
                  onTap: () => _goToJoin(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<_ProfileStat> get _profileStats => [
        _ProfileStat(
          value: '${PlayerSession.instance.gamesPlayed}',
          label: context.l10n.statGames,
          icon: Icons.style_rounded,
          badgeGradient: [Palette.redLight, Palette.red],
        ),
        _ProfileStat(
          value: '${PlayerSession.instance.wins}',
          label: context.l10n.statWins,
          icon: Icons.emoji_events_rounded,
          badgeGradient: [const Color(0xFF5FB98C), Palette.green],
        ),
        _ProfileStat(
          value: '%${PlayerSession.instance.winRatePercent}',
          label: context.l10n.statWinRate,
          icon: Icons.bar_chart_rounded,
          badgeGradient: [Palette.mustardLight, Palette.mustard],
        ),
        _ProfileStat(
          value: '${PlayerSession.instance.bestStreak}',
          label: context.l10n.statBestStreak,
          icon: Icons.local_fire_department_rounded,
          badgeGradient: [const Color(0xFF5B8FC7), Palette.blue],
        ),
      ];

  Widget _profileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.profileTitle, style: AppText.baloo(size: 19, weight: FontWeight.w700)),
              GestureDetector(
                onTap: () async {
                  SoundService.instance.playSfx(Sfx.buttonTap);
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()));
                  if (mounted) setState(() {});
                },
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 15, color: Palette.blue),
                    const SizedBox(width: 4),
                    Text(context.l10n.profileEditButton, style: AppText.nunito(size: 12, weight: FontWeight.w800, color: Palette.blue)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [for (final s in _profileStats) _statCard(s)],
          ),
          const SizedBox(height: 18),
          Text(context.l10n.leaderboardTitle, style: AppText.baloo(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          _leaderboardComingSoon(),
        ],
      ),
    );
  }

  // Çevrimiçi liderlik tablosu sunucu (Aşama 3+) gelmeden gerçek veriyle
  // doldurulamaz; sahte isim/puan göstermek yerine "Yakında" durumu koyduk.
  Widget _leaderboardComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Icon(Icons.leaderboard_rounded, size: 28, color: Palette.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(context.l10n.leaderboardComingSoon, style: AppText.baloo(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            context.l10n.leaderboardComingSoonBody,
            textAlign: TextAlign.center,
            style: AppText.nunito(size: 12, weight: FontWeight.w700, color: Palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statCard(_ProfileStat stat) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
        boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: stat.badgeGradient),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(stat.icon, size: 14, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(stat.value, style: AppText.baloo(size: 20, weight: FontWeight.w800)),
          Text(stat.label, style: AppText.nunito(size: 11, weight: FontWeight.w700, color: Palette.textSecondary)),
        ],
      ),
    );
  }

  void _goToQuickPlay(BuildContext context) {
    SoundService.instance.playSfx(Sfx.screenTransition);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyScreen.quickPlay()));
  }

  void _goToCreateRoom(BuildContext context) {
    SoundService.instance.playSfx(Sfx.screenTransition);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyScreen()));
  }

  void _goToJoin(BuildContext context) {
    SoundService.instance.playSfx(Sfx.screenTransition);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen()));
  }

  Widget _secondaryCard({required String label, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.05), width: 2),
          boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppText.baloo(size: 14, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
