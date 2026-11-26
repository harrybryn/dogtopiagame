import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dogtopia/components/world/settings_dialog.dart';
import 'package:dogtopia/services/audio_service.dart';
import 'package:dogtopia/state/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channelName in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channelName),
        (_) async => null,
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundManager.instance.hasSavedAudioPrefs = false;
    SoundManager.instance.setBgmEnabled(true, persist: false);
    SoundManager.instance.setSfxEnabled(true, persist: false);
    SoundManager.instance.setBgmVolume(0.5, persist: false);
    SoundManager.instance.setSfxVolume(0.8, persist: false);
  });

  testWidgets('SettingsDialog toggles SFX and Music BGM OFF and persists locally',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final game = GameController(startWalkthrough: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsDialog(game: game),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially SFX & BGM are ON (2 ON buttons + 1 OFF for grid)
    expect(find.text('ON'), findsNWidgets(2));
    expect(find.text('OFF'), findsOneWidget);

    // Tap SFX toggle (first ON button)
    await tester.tap(find.text('ON').first);
    await tester.pumpAndSettle();

    expect(game.sfxEnabled, isFalse);
    expect(SoundManager.instance.sfxEnabled, isFalse);
    expect(find.text('ON'), findsOneWidget);
    expect(find.text('OFF'), findsNWidgets(2));

    // Tap Music BGM toggle (remaining ON button)
    await tester.tap(find.text('ON').first);
    await tester.pumpAndSettle();

    expect(game.bgmEnabled, isFalse);
    expect(SoundManager.instance.bgmEnabled, isFalse);
    expect(find.text('ON'), findsNothing);
    expect(find.text('OFF'), findsNWidgets(3));

    // Verify volumes and mute flags were persisted locally
    game.setBgmVolume(0.25);
    game.setSfxVolume(0.35);
    await tester.pump();

    // Reset in-memory flags and reload via SoundManager.init()
    SoundManager.instance.bgmEnabled = true;
    SoundManager.instance.sfxEnabled = true;
    SoundManager.instance.bgmVolume = 1.0;
    SoundManager.instance.sfxVolume = 1.0;

    await tester.runAsync(() => SoundManager.instance.init());
    expect(SoundManager.instance.bgmEnabled, isFalse);
    expect(SoundManager.instance.sfxEnabled, isFalse);
    expect(SoundManager.instance.bgmVolume, closeTo(0.25, 0.001));
    expect(SoundManager.instance.sfxVolume, closeTo(0.35, 0.001));

    game.dispose();
  });
}
