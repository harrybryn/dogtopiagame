import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dogtopia/services/google_auth_service.dart';
import 'package:dogtopia/state/game_controller.dart';
import 'package:dogtopia/components/common/google_sign_in_dialog.dart';
import 'package:dogtopia/components/world/settings_dialog.dart';

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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GoogleAuthService.instance.init();
    if (GoogleAuthService.instance.isSignedIn) {
      await GoogleAuthService.instance.signOut();
    }
  });

  test('GoogleUserData parses, computes initials, and serializes to JSON correctly', () {
    final user = GoogleUserData(
      id: 'goog_123',
      email: 'alex.rivera@gmail.com',
      displayName: 'Alex Rivera',
      linkedAt: 1000,
      lastSyncedAt: 2000,
    );

    expect(user.initials, 'AR');
    expect(user.email, 'alex.rivera@gmail.com');
    expect(user.displayName, 'Alex Rivera');

    final json = user.toJson();
    final restored = GoogleUserData.fromJson(json);

    expect(restored.id, 'goog_123');
    expect(restored.email, 'alex.rivera@gmail.com');
    expect(restored.displayName, 'Alex Rivera');
    expect(restored.linkedAt, 1000);
    expect(restored.lastSyncedAt, 2000);
    expect(restored.initials, 'AR');
  });

  test('GoogleAuthService links account, persists session, and syncs cloud save', () async {
    final game = GameController(startWalkthrough: false);
    addTearDown(game.dispose);

    game.setUsername('CloudKeeper');
    game.addCurrency(coins: 3500, crystals: 25, kibble: 800, xp: 900);

    expect(GoogleAuthService.instance.isSignedIn, isFalse);

    // Link Google account
    final user = await GoogleAuthService.instance.connectAccount(
      email: 'cloud.keeper@gmail.com',
      displayName: 'Cloud Keeper',
      game: game,
    );

    expect(GoogleAuthService.instance.isSignedIn, isTrue);
    expect(GoogleAuthService.instance.currentUser?.email, 'cloud.keeper@gmail.com');
    expect(GoogleAuthService.instance.currentUser?.displayName, 'Cloud Keeper');
    expect(GoogleAuthService.instance.currentUser?.initials, 'CK');
    expect(user.lastSyncedAt, greaterThan(0));

    // Cloud save should be present
    final cloudData = await GoogleAuthService.instance.getCloudSave();
    expect(cloudData, isNotNull);
    expect(cloudData!['playerUsername'], 'CloudKeeper');
    expect(cloudData['coins'], 3500);
    expect(cloudData['crystals'], 25);
    expect(cloudData['googleEmail'], 'cloud.keeper@gmail.com');

    // Simulate new GameController restoring from cloud
    final freshGame = GameController(startWalkthrough: false);
    addTearDown(freshGame.dispose);

    final restored = await GoogleAuthService.instance.restoreCloudSave(freshGame);
    expect(restored, isTrue);
    expect(freshGame.playerUsername, 'CloudKeeper');
    expect(freshGame.coins, 3500);
    expect(freshGame.crystals, 25);

    // Disconnect unlinks user but keeps local save safe
    await GoogleAuthService.instance.signOut();
    expect(GoogleAuthService.instance.isSignedIn, isFalse);
    expect(GoogleAuthService.instance.currentUser, isNull);
  });

  testWidgets('GoogleSignInDialog renders account picker and connects account', (tester) async {
    final game = GameController(startWalkthrough: false);
    addTearDown(game.dispose);
    game.setUsername('IslandHero');

    GoogleUserData? signedInUser;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                signedInUser = await GoogleSignInDialog.show(
                  context,
                  game: game,
                );
              },
              child: const Text('OPEN DIALOG'),
            ),
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('OPEN DIALOG'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Choose an account to continue to Dogtopia'), findsOneWidget);
    expect(find.text('IslandHero'), findsOneWidget);
    expect(find.text('islandhero@gmail.com'), findsOneWidget);

    // Tap account to connect
    await tester.tap(find.text('IslandHero'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(signedInUser, isNotNull);
    expect(signedInUser?.displayName, 'IslandHero');
    expect(signedInUser?.email, 'islandhero@gmail.com');
    expect(GoogleAuthService.instance.isSignedIn, isTrue);
  });

  testWidgets('SettingsDialog displays Connect with Google and updates to Connected state', (tester) async {
    final game = GameController(startWalkthrough: false);
    addTearDown(game.dispose);
    game.setUsername('SettingsTester');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsDialog(game: game),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial "NOT CONNECTED" state
    expect(find.text('CLOUD ACCOUNT BACKUP'), findsOneWidget);
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    expect(find.text('Connect with Google'), findsOneWidget);

    // Link account directly to simulate successful sign in
    await GoogleAuthService.instance.connectAccount(
      email: 'tester@gmail.com',
      displayName: 'Settings Tester',
      game: game,
    );
    await tester.pumpAndSettle();

    // Verify dynamically updated "CONNECTED" state
    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.text('Settings Tester'), findsOneWidget);
    expect(find.text('tester@gmail.com'), findsOneWidget);
    expect(find.text('SYNC NOW'), findsOneWidget);
    expect(find.text('RESTORE'), findsOneWidget);
    expect(find.text('DISCONNECT'), findsOneWidget);
  });
}
