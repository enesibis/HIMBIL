import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himbil/audio/sound_service.dart';
import 'package:himbil/l10n/app_localizations.dart';
import 'package:himbil/screens/privacy_policy_screen.dart';
import 'package:himbil/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// See settings_screen_test.dart's identical helper for why this is needed:
/// [SoundService] eagerly constructs real `AudioPlayer`s on first touch,
/// which reach for a platform channel with no test-mode backend.
void _mockAudioplayersChannels() {
  const channels = ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global'];
  for (final name in channels) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      MethodChannel(name),
      (call) async => null,
    );
  }
}

/// Madde #61's golden-test subset: two static, fully-owned screens with no
/// timers/animations/network — the lowest-risk starting point for visual
/// regression coverage. Regenerate with `flutter test --update-goldens`
/// after an intentional visual change.
///
/// Caveat: Flutter renders goldens deterministically for a given engine
/// version regardless of host OS (it rasterizes via Skia, not native OS
/// text shaping), but a *different* Flutter/engine version than the one
/// these were generated with can still shift a few pixels — if CI ever
/// flags these as failing right after a Flutter upgrade with no visual
/// intent behind it, that's why; just regenerate.
/// AudioPlayer also opens a per-instance position/duration EventChannel
/// (named with a fresh UUID per player, so it can't be pre-mocked by name
/// like the two channels above) — under `matchesGoldenFile`'s extra pumping
/// this surfaces as a MissingPluginException. It doesn't affect the
/// rendered pixels (nothing here depends on playback position), so it's
/// filtered instead of failing an otherwise-passing golden comparison.
///
/// This has to be set from *inside* the `testWidgets` callback, not
/// `setUp` — `TestWidgetsFlutterBinding.runTest` installs its own
/// `FlutterError.onError` (to power `tester.takeException()`) after `setUp`
/// hooks run but before the test body executes, which would otherwise
/// clobber a handler installed in `setUp`.
void _suppressAudioplayersNoise() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('xyz.luan/audioplayers')) return;
    original?.call(details);
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockAudioplayersChannels();
  });

  Widget localizedApp(Widget home) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  testWidgets('SettingsScreen matches its golden image', (tester) async {
    _suppressAudioplayersNoise();
    tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SoundService.instance.sfxEnabled = true;
    SoundService.instance.musicEnabled = true;

    await tester.pumpWidget(localizedApp(const SettingsScreen()));
    await tester.pumpAndSettle();

    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/settings_screen.png'));
  });

  testWidgets('PrivacyPolicyScreen matches its golden image', (tester) async {
    tester.view.physicalSize = const Size(402, 874) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(localizedApp(const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    await expectLater(find.byType(PrivacyPolicyScreen), matchesGoldenFile('goldens/privacy_policy_screen.png'));
  });
}
