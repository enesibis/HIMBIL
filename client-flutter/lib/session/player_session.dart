import 'package:shared_preferences/shared_preferences.dart';

import '../theme/avatar_options.dart';

/// Oturum boyunca geçerli, cihazda kalıcı tutulan oyuncu profili.
/// Gerçek hesap sistemi (Aşama 7) gelene kadar sadece cihaz-yerel bir
/// profil (isim, yaş, avatar seçimleri) tutulur; sunucuya senkronize edilmez.
class PlayerSession {
  PlayerSession._();

  static const _keyOnboarded = 'has_onboarded';
  static const _keyName = 'player_name';
  static const _keyAge = 'player_age';
  static const _keyCharacterIndex = 'avatar_character_index';
  static const _keyColorIndex = 'avatar_color_index';
  static const _keyFrameIndex = 'avatar_frame_index';

  static bool hasOnboarded = false;
  static String name = 'Sen';
  static int age = 18;
  static int avatarCharacterIndex = 0;
  static int avatarColorIndex = 0;
  static AvatarFrame avatarFrame = AvatarFrame.classic;

  static String get initial => name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

  static AvatarCharacterOption get avatarCharacter =>
      AvatarOptions.characters[avatarCharacterIndex.clamp(0, AvatarOptions.characters.length - 1)];

  static AvatarColorOption get avatarColor => AvatarOptions.colors[avatarColorIndex.clamp(0, AvatarOptions.colors.length - 1)];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    hasOnboarded = prefs.getBool(_keyOnboarded) ?? false;
    name = prefs.getString(_keyName) ?? 'Sen';
    age = prefs.getInt(_keyAge) ?? 18;
    avatarCharacterIndex = prefs.getInt(_keyCharacterIndex) ?? 0;
    avatarColorIndex = prefs.getInt(_keyColorIndex) ?? 0;
    final frameIndex = prefs.getInt(_keyFrameIndex) ?? 0;
    avatarFrame = AvatarFrame.values[frameIndex.clamp(0, AvatarFrame.values.length - 1)];
  }

  static Future<void> completeOnboarding() async {
    hasOnboarded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, true);
    await prefs.setString(_keyName, name);
    await prefs.setInt(_keyAge, age);
    await prefs.setInt(_keyCharacterIndex, avatarCharacterIndex);
    await prefs.setInt(_keyColorIndex, avatarColorIndex);
    await prefs.setInt(_keyFrameIndex, AvatarFrame.values.indexOf(avatarFrame));
  }
}
