import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/audio/sound_service.dart';
import 'package:himbil/l10n/app_localizations.dart';
import 'package:himbil/screens/privacy_policy_screen.dart';
import 'package:himbil/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localizedApp(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// [SoundService] eagerly constructs a pool of real `AudioPlayer`s the
/// first time it's touched, which reaches for these platform channels —
/// there's no test-mode audio backend, so without a mock the plugin calls
/// throw `MissingPluginException` asynchronously and can flakily attribute
/// themselves to whichever test happens to be running when they land.
void _mockAudioplayersChannels() {
  const channels = ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global'];
  for (final name in channels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockAudioplayersChannels();
    SoundService.instance.sfxEnabled = true;
    SoundService.instance.musicEnabled = true;
  });

  testWidgets('shows current sound/music state and toggling persists it', (tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_localizedApp(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Ses Efektleri'), findsOneWidget);
    expect(find.text('Müzik'), findsOneWidget);

    final sfxSwitchFinder = find.byType(Switch).first;
    var sfxSwitch = tester.widget<Switch>(sfxSwitchFinder);
    expect(sfxSwitch.value, isTrue);

    await tester.tap(sfxSwitchFinder);
    await tester.pumpAndSettle();

    sfxSwitch = tester.widget<Switch>(sfxSwitchFinder);
    expect(sfxSwitch.value, isFalse);
    expect(SoundService.instance.sfxEnabled, isFalse);
  });

  testWidgets('navigates to the privacy policy screen', (tester) async {
    _setPhoneSize(tester);
    await tester.pumpWidget(_localizedApp(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gizlilik Politikası'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });
}
