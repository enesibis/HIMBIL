import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/l10n/app_localizations.dart';
import 'package:himbil/screens/profile_edit_screen.dart';
import 'package:himbil/session/player_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _localizedApp(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerSession.instance = PlayerSession()
      ..name = 'Eski İsim'
      ..age = 20
      ..avatarCharacterIndex = 0
      ..avatarColorIndex = 0;
  });

  testWidgets('pre-fills current name/age and saves edits back to PlayerSession', (tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_localizedApp(const ProfileEditScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Eski İsim'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    await tester.enterText(find.text('Eski İsim'), 'Yeni İsim');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(PlayerSession.instance.name, 'Yeni İsim');
    expect(PlayerSession.instance.age, 21);
  });

  testWidgets('does not save an empty name', (tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_localizedApp(const ProfileEditScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.text('Eski İsim'), '   ');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(PlayerSession.instance.name, 'Eski İsim');
    expect(find.byType(ProfileEditScreen), findsOneWidget);
  });
}
