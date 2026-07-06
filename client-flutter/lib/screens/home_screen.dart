import 'package:flutter/material.dart';

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

class _ProfileStat {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> badgeGradient;

  const _ProfileStat({required this.value, required this.label, required this.icon, required this.badgeGradient});
}

class _LeaderboardRow {
  final int rank;
  final String name;
  final int score;

  const _LeaderboardRow({required this.rank, required this.name, required this.score});
}

const _profileStats = [
  _ProfileStat(value: '47', label: 'Oyun', icon: Icons.style_rounded, badgeGradient: [Palette.redLight, Palette.red]),
  _ProfileStat(value: '19', label: 'Galibiyet', icon: Icons.emoji_events_rounded, badgeGradient: [Color(0xFF5FB98C), Palette.green]),
  _ProfileStat(value: '%40', label: 'Kazanma Oranı', icon: Icons.bar_chart_rounded, badgeGradient: [Palette.mustardLight, Palette.mustard]),
  _ProfileStat(value: '5', label: 'En İyi Seri', icon: Icons.local_fire_department_rounded, badgeGradient: [Color(0xFF5B8FC7), Palette.blue]),
];

const _otherLeaderboardRows = [
  _LeaderboardRow(rank: 1, name: 'Deniz K.', score: 2450),
  _LeaderboardRow(rank: 3, name: 'Ayşe Y.', score: 1620),
  _LeaderboardRow(rank: 4, name: 'Mehmet A.', score: 1400),
  _LeaderboardRow(rank: 5, name: 'Zeynep T.', score: 1180),
];

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
            Text('Hımbıl', style: AppText.baloo(size: 23, weight: FontWeight.w800)),
          ],
        ),
        UserAvatar(
          size: 40,
          imagePath: PlayerSession.avatarCharacter.imagePath,
          initial: PlayerSession.initial,
          gradient: PlayerSession.avatarColor.gradient,
          frame: PlayerSession.avatarFrame,
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
          Text('Merhaba,', style: AppText.nunito(size: 14, weight: FontWeight.w700, color: Palette.textSecondary)),
          const SizedBox(height: 2),
          Text('Bugün Hımbıl var!', style: AppText.baloo(size: 23, weight: FontWeight.w700)),
          const SizedBox(height: 20),
          GradientCta(
            title: '▶  HIZLI OYNA',
            subtitle: 'Rastgele oyuncularla eşleş',
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
                child: Text('VEYA ÖZEL ODA', style: AppText.nunito(size: 11, weight: FontWeight.w800, color: Palette.textSecondary)),
              ),
              Expanded(child: Divider(color: Palette.textPrimary.withValues(alpha: 0.1), thickness: 2)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _secondaryCard(
                  label: 'Oda Kur',
                  icon: Icons.add_rounded,
                  iconColor: Palette.mustard,
                  onTap: () => _goToCreateRoom(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _secondaryCard(
                  label: 'Kodla Katıl',
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

  List<_LeaderboardRow> get _leaderboard => [
        ..._otherLeaderboardRows.where((r) => r.rank < 2),
        _LeaderboardRow(rank: 2, name: PlayerSession.name, score: 1875),
        ..._otherLeaderboardRows.where((r) => r.rank > 2),
      ];

  Widget _profileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profilim', style: AppText.baloo(size: 19, weight: FontWeight.w700)),
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
          Text('Liderlik Tablosu', style: AppText.baloo(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Palette.textPrimary.withValues(alpha: 0.04), width: 2),
              boxShadow: [BoxShadow(color: Palette.textPrimary.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _leaderboard.length; i++) _leaderboardRow(_leaderboard[i], isLast: i == _leaderboard.length - 1),
              ],
            ),
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

  Widget _leaderboardRow(_LeaderboardRow row, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Palette.textPrimary.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          SizedBox(width: 16, child: Text('${row.rank}', style: AppText.baloo(size: 13, weight: FontWeight.w800, color: Palette.textSecondary))),
          const SizedBox(width: 10),
          Expanded(child: Text(row.name, style: AppText.nunito(size: 14, weight: FontWeight.w700))),
          Text('${row.score}', style: AppText.baloo(size: 14, weight: FontWeight.w800, color: Palette.red)),
        ],
      ),
    );
  }

  void _goToQuickPlay(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyScreen.quickPlay()));
  }

  void _goToCreateRoom(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LobbyScreen()));
  }

  void _goToJoin(BuildContext context) {
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
