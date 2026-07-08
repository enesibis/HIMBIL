import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kısa oyun içi efektler — [SoundService.playSfx] ile çalınır.
/// Yol, `assets/` öneki `AudioPlayer`'ın varsayılan `AudioCache.prefix`'i
/// tarafından otomatik eklendiği için `assets/` olmadan yazılır.
enum Sfx {
  buttonTap('sounds/sfx_ui_button_tap.mp3'),
  screenTransition('sounds/sfx_ui_screen_transition.mp3'),
  stepForward('sounds/sfx_ui_step_forward.mp3'),
  avatarSelect('sounds/sfx_ui_avatar_select.mp3'),
  lobbyJoinSuccess('sounds/sfx_lobby_join_success.mp3'),
  lobbyPlayerJoined('sounds/sfx_lobby_player_joined.mp3'),
  lobbyCountdownTick('sounds/sfx_lobby_countdown_tick.mp3'),
  dealCards('sounds/sfx_game_deal_cards.mp3'),
  swapTick('sounds/sfx_game_swap_tick.mp3'),
  cardSelect('sounds/sfx_game_card_select.mp3'),
  countdownTick('sounds/sfx_game_countdown_tick.mp3'),
  slamPress('sounds/sfx_game_slam_press.mp3'),
  slamCorrect('sounds/sfx_game_slam_correct.mp3'),
  falseSlam('sounds/sfx_game_false_slam.mp3'),
  slamRankEcho('sounds/sfx_game_slam_rank_echo.mp3'),
  roundDing('sounds/sfx_result_round_ding.mp3'),
  slamFanfare('sounds/sfx_result_slam_fanfare.mp3'),
  gameWin('sounds/sfx_result_game_win.mp3'),
  gameLose('sounds/sfx_result_game_lose.mp3'),
  rankPop('sounds/sfx_result_rank_pop.mp3');

  const Sfx(this.assetPath);
  final String assetPath;
}

/// Döngülü/uzun parçalar — [SoundService.playMusic] ile çalınır.
enum MusicTrack {
  menuLoop('music/music_menu_loop.mp3'),
  gameLoop('music/music_game_loop.mp3'),
  splashJingle('music/music_splash_jingle.mp3');

  const MusicTrack(this.assetPath);
  final String assetPath;
}

/// Uygulama boyunca paylaşılan tekil ses servisi (bkz. [PlayerSession] ile
/// aynı static-instance deseni).
///
/// SFX'ler için birden fazla [AudioPlayer] havuzda tutulur — tek bir player
/// üzerinde art arda `play()` çağırmak öncekini keser, oysa örn. sıralama
/// ekranındaki 4 oyuncunun art arda basış sesleri üst üste binmeli.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _poolSize = 6;
  final List<AudioPlayer> _pool = List.generate(_poolSize, (_) => AudioPlayer());
  int _nextPlayer = 0;

  final AudioPlayer _music = AudioPlayer();

  bool sfxEnabled = true;
  bool musicEnabled = true;

  static const _sfxEnabledKey = 'settings_sfx_enabled';
  static const _musicEnabledKey = 'settings_music_enabled';

  /// SFX havuzunu düşük gecikmeli oynatma moduna alır ve madde #53'ün
  /// Ayarlar ekranından değiştirilen ses/müzik tercihini geri yükler;
  /// `main()`'de [PlayerSession.load] ile birlikte bir kez çağrılmalı.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    sfxEnabled = prefs.getBool(_sfxEnabledKey) ?? true;
    musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    for (final player in _pool) {
      await player.setPlayerMode(PlayerMode.lowLatency);
    }
  }

  Future<void> setSfxEnabled(bool value) async {
    sfxEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxEnabledKey, value);
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, value);
    if (!value) await stopMusic();
  }

  Future<void> playSfx(Sfx sfx) async {
    if (!sfxEnabled) return;
    final player = _pool[_nextPlayer];
    _nextPlayer = (_nextPlayer + 1) % _pool.length;
    await player.stop();
    await player.play(AssetSource(sfx.assetPath));
  }

  Future<void> playMusic(MusicTrack track, {bool loop = true}) async {
    if (!musicEnabled) return;
    await _music.stop();
    await _music.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    await _music.play(AssetSource(track.assetPath));
  }

  Future<void> stopMusic() => _music.stop();

  Future<void> setMusicVolume(double volume) => _music.setVolume(volume);

  void dispose() {
    for (final player in _pool) {
      player.dispose();
    }
    _music.dispose();
  }
}
