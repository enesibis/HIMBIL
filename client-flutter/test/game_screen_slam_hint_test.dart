import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/l10n/l10n.dart';
import 'package:himbil/screens/game_screen.dart';
import 'package:himbil/session/player_session.dart';
import 'package:himbil/widgets/himbil_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _slamHintText = "4'lün tamam — HIMBIL'e bas!";

/// Testin varsayılan 800x600 (yatay) yüzeyi, oyun ekranının dikey düzenini
/// yansıtmıyor (bkz. widget_test.dart'taki _setPhoneSize notu).
void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Slam ipucu metni yalnız insanın eli gerçekten 4'lüyken görünmeli (bkz.
/// game_screen.dart'taki `showSlamHint` ve `_humanHasQuartet`). `HimbilCard`
/// yalnız insanın elini oluşturmak için kullanılıyor (bots.dart/opponent_fan
/// ayrı bir widget kullanıyor), o yüzden ağaçtaki HimbilCard'ların
/// objectType'larını okuyup gerçek bir 4'lü olup olmadığını doğrudan
/// doğrulayabiliriz — metnin görünürlüğü bununla her zaman tutarlı olmalı.
void _expectHintOnlyWhenQuartet(WidgetTester tester) {
  if (find.text(_slamHintText).evaluate().isEmpty) return;
  final cards = tester.widgetList<HimbilCard>(find.byType(HimbilCard)).toList();
  if (cards.length != 4) return; // pas-relay animasyonu sırasında geçici sayım farkı olabilir
  final types = cards.map((c) => c.objectType).toSet();
  expect(
    types.length,
    1,
    reason: "Slam ipucu, insanın eli 4'lü değilken render edildi: ${cards.map((c) => c.objectType).toList()}",
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerSession.instance = PlayerSession()..hasSeenTutorial = true;
  });

  testWidgets(
    "İnsanın 4'lüsü yokken '4'lün tamam — HIMBIL'e bas!' metni asla render edilmez",
    (tester) async {
      _setPhoneSize(tester);
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('tr'),
        home: GameScreen(),
      ));
      await tester.pump();

      _expectHintOnlyWhenQuartet(tester);
      // Birden fazla takas tick'i + en az bir slam penceresini kapsayacak
      // kadar ilerlet; simüle edilen süre olduğu için gerçek zamanda hızlı.
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        _expectHintOnlyWhenQuartet(tester);
      }
    },
  );
}
