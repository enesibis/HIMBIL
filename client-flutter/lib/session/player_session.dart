import 'package:shared_preferences/shared_preferences.dart';

import '../theme/avatar_frames.dart';
import '../theme/avatar_options.dart';
import '../theme/card_skins.dart';

/// Oturum boyunca geçerli, cihazda kalıcı tutulan oyuncu profili.
/// Gerçek hesap sistemi (Aşama 7) gelene kadar sadece cihaz-yerel bir
/// profil (isim, yaş, avatar seçimleri, mağaza envanteri) tutulur;
/// sunucuya senkronize edilmez.
class PlayerSession {
  PlayerSession._();

  static const _keyOnboarded = 'has_onboarded';
  static const _keyName = 'player_name';
  static const _keyAge = 'player_age';
  static const _keyCharacterIndex = 'avatar_character_index';
  static const _keyColorIndex = 'avatar_color_index';
  static const _keyFrameId = 'avatar_frame_id';
  static const _keyTokens = 'player_tokens';
  static const _keyOwnedCardSkins = 'owned_card_skins';
  static const _keySelectedCardSkin = 'selected_card_skin';
  static const _keyOwnedFrames = 'owned_avatar_frames';
  static const _keyGamesPlayed = 'stats_games_played';
  static const _keyWins = 'stats_wins';
  static const _keyBestStreak = 'stats_best_streak';
  static const _keyCurrentStreak = 'stats_current_streak';
  static const _keyHasSeenTutorial = 'has_seen_tutorial';

  static const _startingTokens = 500;

  static bool hasOnboarded = false;
  static String name = 'Sen';
  static int age = 18;
  static int avatarCharacterIndex = 0;
  static int avatarColorIndex = 0;
  static String avatarFrame = AvatarFrameSkins.defaultFrameId;

  static int tokens = _startingTokens;
  static Set<String> ownedCardSkinIds = {'klasik', 'karnaval'};
  static String selectedCardSkinId = CardSkins.defaultSkinId;
  static Set<String> ownedFrameIds = {for (final f in AvatarFrameSkins.all) if (f.isFree) f.id};

  static int gamesPlayed = 0;
  static int wins = 0;
  static int bestStreak = 0;
  static int currentStreak = 0;
  static bool hasSeenTutorial = false;

  static int get winRatePercent => gamesPlayed == 0 ? 0 : ((wins / gamesPlayed) * 100).round();

  static String get initial => name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

  static AvatarCharacterOption get avatarCharacter =>
      AvatarOptions.characters[avatarCharacterIndex.clamp(0, AvatarOptions.characters.length - 1)];

  static AvatarColorOption get avatarColor => AvatarOptions.colors[avatarColorIndex.clamp(0, AvatarOptions.colors.length - 1)];

  static bool ownsCardSkin(String id) => ownedCardSkinIds.contains(id);

  static bool ownsFrame(String id) => ownedFrameIds.contains(id);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hasOnboarded = prefs.getBool(_keyOnboarded) ?? false;
    name = prefs.getString(_keyName) ?? 'Sen';
    age = prefs.getInt(_keyAge) ?? 18;
    avatarCharacterIndex = prefs.getInt(_keyCharacterIndex) ?? 0;
    avatarColorIndex = prefs.getInt(_keyColorIndex) ?? 0;
    avatarFrame = prefs.getString(_keyFrameId) ?? AvatarFrameSkins.defaultFrameId;

    tokens = prefs.getInt(_keyTokens) ?? _startingTokens;
    selectedCardSkinId = prefs.getString(_keySelectedCardSkin) ?? CardSkins.defaultSkinId;
    ownedCardSkinIds = (prefs.getStringList(_keyOwnedCardSkins) ?? const ['klasik', 'karnaval']).toSet();
    ownedCardSkinIds.add(selectedCardSkinId);

    final savedFrames = prefs.getStringList(_keyOwnedFrames);
    ownedFrameIds = savedFrames?.toSet() ?? {for (final f in AvatarFrameSkins.all) if (f.isFree) f.id};
    // Onboarding'de serbestçe seçilmiş olabileceği için mevcut çerçeve her zaman sahiplenilmiş sayılır.
    ownedFrameIds.add(avatarFrame);

    gamesPlayed = prefs.getInt(_keyGamesPlayed) ?? 0;
    wins = prefs.getInt(_keyWins) ?? 0;
    bestStreak = prefs.getInt(_keyBestStreak) ?? 0;
    currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    hasSeenTutorial = prefs.getBool(_keyHasSeenTutorial) ?? false;
  }

  static Future<void> completeOnboarding() async {
    hasOnboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, true);
    await prefs.setString(_keyName, name);
    await prefs.setInt(_keyAge, age);
    await prefs.setInt(_keyCharacterIndex, avatarCharacterIndex);
    await prefs.setInt(_keyColorIndex, avatarColorIndex);
    await prefs.setString(_keyFrameId, avatarFrame);
    ownedFrameIds.add(avatarFrame);
    await prefs.setStringList(_keyOwnedFrames, ownedFrameIds.toList());
  }

  /// Kartı satın alır; yeterli jeton yoksa veya zaten sahipse false döner.
  static Future<bool> purchaseCardSkin(String id) async {
    if (ownsCardSkin(id)) return true;
    final skin = CardSkins.byId(id);
    if (tokens < skin.price) return false;
    tokens -= skin.price;
    ownedCardSkinIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTokens, tokens);
    await prefs.setStringList(_keyOwnedCardSkins, ownedCardSkinIds.toList());
    return true;
  }

  static Future<void> selectCardSkin(String id) async {
    if (!ownsCardSkin(id)) return;
    selectedCardSkinId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedCardSkin, id);
  }

  /// Çerçeveyi satın alır; yeterli jeton yoksa veya zaten sahipse false döner.
  static Future<bool> purchaseFrame(String id) async {
    if (ownsFrame(id)) return true;
    final price = AvatarFrameSkins.byId(id).price;
    if (tokens < price) return false;
    tokens -= price;
    ownedFrameIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTokens, tokens);
    await prefs.setStringList(_keyOwnedFrames, ownedFrameIds.toList());
    return true;
  }

  static Future<void> selectFrame(String id) async {
    if (!ownsFrame(id)) return;
    avatarFrame = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFrameId, id);
  }

  static Future<void> addTokens(int amount, String reason) async {
    tokens += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTokens, tokens);
  }

  /// Maç sonunda bir kez çağrılır; oyun/galibiyet sayısını ve serileri günceller.
  static Future<void> recordMatchResult({required bool won}) async {
    gamesPlayed++;
    if (won) {
      wins++;
      currentStreak++;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
    } else {
      currentStreak = 0;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGamesPlayed, gamesPlayed);
    await prefs.setInt(_keyWins, wins);
    await prefs.setInt(_keyBestStreak, bestStreak);
    await prefs.setInt(_keyCurrentStreak, currentStreak);
  }

  static Future<void> markTutorialSeen() async {
    hasSeenTutorial = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenTutorial, true);
  }
}
