import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/session/player_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('purchaseCardSkin', () {
    test('deducts tokens and adds the skin to inventory when affordable', () async {
      final session = PlayerSession()..tokens = 500;
      final ok = await session.purchaseCardSkin('retro'); // price 200
      expect(ok, isTrue);
      expect(session.tokens, 300);
      expect(session.ownsCardSkin('retro'), isTrue);
    });

    test('fails and leaves tokens untouched when unaffordable', () async {
      final session = PlayerSession()..tokens = 100;
      final ok = await session.purchaseCardSkin('retro'); // price 200
      expect(ok, isFalse);
      expect(session.tokens, 100);
      expect(session.ownsCardSkin('retro'), isFalse);
    });

    test('returns true without charging when already owned', () async {
      final session = PlayerSession()..tokens = 50; // klasik is free & pre-owned
      final ok = await session.purchaseCardSkin('klasik');
      expect(ok, isTrue);
      expect(session.tokens, 50);
    });

    test('persists the new balance and inventory to SharedPreferences', () async {
      final session = PlayerSession()..tokens = 500;
      await session.purchaseCardSkin('retro');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('player_tokens'), 300);
      expect(prefs.getStringList('owned_card_skins'), contains('retro'));
    });
  });

  group('purchaseFrame', () {
    test('deducts tokens and adds the frame to inventory when affordable', () async {
      final session = PlayerSession()..tokens = 500;
      final ok = await session.purchaseFrame('simit'); // price 250
      expect(ok, isTrue);
      expect(session.tokens, 250);
      expect(session.ownsFrame('simit'), isTrue);
    });

    test('fails and leaves tokens untouched when unaffordable', () async {
      final session = PlayerSession()..tokens = 10;
      final ok = await session.purchaseFrame('simit');
      expect(ok, isFalse);
      expect(session.tokens, 10);
      expect(session.ownsFrame('simit'), isFalse);
    });

    test('returns true without charging when already owned', () async {
      final session = PlayerSession()..tokens = 50; // standart is free & pre-owned
      final ok = await session.purchaseFrame('standart');
      expect(ok, isTrue);
      expect(session.tokens, 50);
    });
  });

  group('selectCardSkin / selectFrame', () {
    test('selectCardSkin is a no-op when the skin is not owned', () async {
      final session = PlayerSession();
      final before = session.selectedCardSkinId;
      await session.selectCardSkin('retro'); // never purchased
      expect(session.selectedCardSkinId, before);
    });

    test('selectCardSkin switches the active skin once owned', () async {
      final session = PlayerSession()..tokens = 500;
      await session.purchaseCardSkin('retro');
      await session.selectCardSkin('retro');
      expect(session.selectedCardSkinId, 'retro');
    });

    test('selectFrame is a no-op when the frame is not owned', () async {
      final session = PlayerSession();
      final before = session.avatarFrame;
      await session.selectFrame('tac'); // never purchased
      expect(session.avatarFrame, before);
    });
  });

  group('addTokens', () {
    test('increases the balance and persists it', () async {
      final session = PlayerSession()..tokens = 100;
      await session.addTokens(50, 'match_reward');
      expect(session.tokens, 150);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('player_tokens'), 150);
    });
  });

  group('recordMatchResult', () {
    test('a win increments games/wins and extends both streaks', () async {
      final session = PlayerSession();
      await session.recordMatchResult(won: true);
      await session.recordMatchResult(won: true);
      expect(session.gamesPlayed, 2);
      expect(session.wins, 2);
      expect(session.currentStreak, 2);
      expect(session.bestStreak, 2);
      expect(session.winRatePercent, 100);
    });

    test('a loss resets the current streak but keeps the best streak', () async {
      final session = PlayerSession();
      await session.recordMatchResult(won: true);
      await session.recordMatchResult(won: true);
      await session.recordMatchResult(won: false);
      expect(session.gamesPlayed, 3);
      expect(session.wins, 2);
      expect(session.currentStreak, 0);
      expect(session.bestStreak, 2);
      expect(session.winRatePercent, 67);
    });
  });

  group('load', () {
    test('restores balance, inventory, and stats saved by a previous session', () async {
      final first = PlayerSession()..tokens = 500;
      await first.purchaseCardSkin('retro');
      await first.purchaseFrame('simit');
      await first.recordMatchResult(won: true);
      await first.markTutorialSeen();
      first.name = 'Test Oyuncu';
      first.age = 21;
      await first.completeOnboarding();

      // Aynı mock SharedPreferences deposunu paylaşan taze bir instance,
      // uygulamanın yeniden başlatılmasını simüle eder.
      final second = PlayerSession();
      await second.load();

      expect(second.tokens, 50); // 500 - 200 (retro) - 250 (simit)
      expect(second.ownsCardSkin('retro'), isTrue);
      expect(second.ownsFrame('simit'), isTrue);
      expect(second.gamesPlayed, 1);
      expect(second.wins, 1);
      expect(second.hasSeenTutorial, isTrue);
      expect(second.hasOnboarded, isTrue);
      expect(second.name, 'Test Oyuncu');
      expect(second.age, 21);
    });

    test('falls back to defaults when nothing was ever saved', () async {
      final session = PlayerSession();
      await session.load();
      expect(session.tokens, 500);
      expect(session.hasOnboarded, isFalse);
      expect(session.ownsCardSkin('klasik'), isTrue);
      expect(session.ownsCardSkin('karnaval'), isTrue);
    });
  });

  group('markTutorialSeen', () {
    test('sets the flag and persists it', () async {
      final session = PlayerSession();
      expect(session.hasSeenTutorial, isFalse);
      await session.markTutorialSeen();
      expect(session.hasSeenTutorial, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_seen_tutorial'), isTrue);
    });
  });
}
