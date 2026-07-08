import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:himbil/main.dart';
import 'package:himbil/session/player_session.dart';

/// Açılış animasyonu (1410ms) + bekleme (650ms) + sayfa geçişi süresince
/// pumpAndSettle tek başına yeterli değil: animasyon tamamlanınca yeni kare
/// planlanmadığı için Future.delayed tabanlı geçiş hiç tetiklenmeden durur.
Future<void> _skipSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Testin varsayılan 800x600 (yatay) yüzeyi, uygulamanın hedeflediği dikey
/// telefon oranını hiç yansıtmıyor — oyun ekranındaki 4 oyunculu düzen bu
/// yüzeyde suni bir taşmayla karşılaşır. Gerçekçi bir dikey telefon boyutu
/// (design_handoff'taki 402x874 referans çerçevesiyle aynı) kullanıyoruz.
void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerSession.instance = PlayerSession()..hasOnboarded = true;
  });

  testWidgets('Ana menü açılır ve HIZLI OYNA butonu görünür', (WidgetTester tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(const HimbilApp());
    await _skipSplash(tester);

    expect(find.text('Hımbıl'), findsWidgets);
    expect(find.textContaining('HIZLI OYNA'), findsOneWidget);
  });

  testWidgets('Hızlı Oyna -> otomatik eşleşme -> Oyun ekranı', (WidgetTester tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(const HimbilApp());
    await _skipSplash(tester);

    await tester.tap(find.textContaining('HIZLI OYNA'));
    await tester.pumpAndSettle();

    // Hızlı Oyna'da paylaşılacak bir oda kodu yok; manuel başlatma da yok.
    expect(find.text('HIZLI EŞLEŞME'), findsOneWidget);
    expect(find.text('ODA KODU'), findsNothing);
    expect(find.text('Oyunu Başlat'), findsNothing);

    // Botların "Hazır" olması + otomatik oyun başlangıcı için bekle.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('< Menü'), findsOneWidget);
  });

  testWidgets('Oda Kur -> Lobi -> Oyunu Başlat -> Oyun ekranı', (WidgetTester tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(const HimbilApp());
    await _skipSplash(tester);

    await tester.tap(find.text('Oda Kur'));
    await tester.pumpAndSettle();

    expect(find.text('ODA KODU'), findsOneWidget);
    expect(find.text('Oyunu Başlat'), findsOneWidget);

    // Botların "Hazır" olması için bekle.
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oyunu Başlat'));
    await tester.pumpAndSettle();

    expect(find.text('HIMBIL!'), findsOneWidget);
  });
}
