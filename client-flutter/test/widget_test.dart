import 'package:flutter_test/flutter_test.dart';

import 'package:himbil/main.dart';

void main() {
  testWidgets('Ana menü açılır ve HIZLI OYNA butonu görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const HimbilApp());
    await tester.pumpAndSettle();

    expect(find.text('Hımbıl'), findsWidgets);
    expect(find.textContaining('HIZLI OYNA'), findsOneWidget);
  });

  testWidgets('Oyna -> Lobi -> Oyunu Başlat -> Oyun ekranı', (WidgetTester tester) async {
    await tester.pumpWidget(const HimbilApp());
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('HIZLI OYNA'));
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
