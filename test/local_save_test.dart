import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dogtopia/services/local_save_service.dart';
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
  });

  test('LocalSaveService persists and restores username and game progress', () async {
    final original = GameController();
    addTearDown(original.dispose);

    original.setUsername('BarkMaster');
    original.addCurrency(coins: 1250, crystals: 10, kibble: 400, xp: 600);
    original.unlockLot1();
    original.skipWalkthrough();

    final saved = await LocalSaveService.instance.saveNow(original);
    expect(saved, isTrue);

    final restored = GameController();
    addTearDown(restored.dispose);

    final loaded = await LocalSaveService.instance.loadInto(restored);
    expect(loaded, isTrue);
    expect(restored.playerUsername, 'BarkMaster');
    expect(restored.hasUsername, isTrue);
    expect(restored.coins, original.coins);
    expect(restored.crystals, original.crystals);
    expect(restored.kibble, original.kibble);
    expect(restored.level, original.level);
    expect(restored.xp, original.xp);
    expect(restored.isLot1Unlocked, isTrue);
    expect(restored.walkthroughCompleted, isTrue);
    expect(restored.walkthroughActive, isFalse);
  });

  test('LocalSaveService returns false when no local save exists', () async {
    final game = GameController();
    addTearDown(game.dispose);

    final loaded = await LocalSaveService.instance.loadInto(game);
    expect(loaded, isFalse);
    expect(game.hasUsername, isFalse);
    expect(game.walkthroughActive, isTrue);
  });

  test('Milestone rewards unlock every 5 levels, claim once, and persist locally',
      () async {
    final game = GameController(startWalkthrough: false);
    addTearDown(game.dispose);

    game.setUsername('LevelTester');
    // Level up to Level 4 -> no 5-level milestone unlock yet
    game.addCurrency(xp: 500 + 650 + 845);
    expect(game.level, 4);
    expect(game.unclaimedMilestoneCount, 0);
    expect(game.canClaimMilestone(5), isFalse);

    // Push past Level 5 -> Level 5 milestone becomes claimable
    game.addCurrency(xp: 1200);
    expect(game.level, greaterThanOrEqualTo(5));
    expect(game.unclaimedMilestoneCount, 1);
    expect(game.canClaimMilestone(5), isTrue);

    final coinsBefore = game.coins;
    final crystalsBefore = game.crystals;
    final kibbleBefore = game.kibble;

    expect(game.claimLevelMilestone(5), isTrue);
    expect(game.coins, coinsBefore + 1500);
    expect(game.crystals, crystalsBefore + 10);
    expect(game.kibble, kibbleBefore + 500);
    expect(game.unclaimedMilestoneCount, 0);
    expect(game.claimLevelMilestone(5), isFalse);

    // Save & reload preserves claimed milestones
    await LocalSaveService.instance.saveNow(game);
    final restored = GameController();
    addTearDown(restored.dispose);
    await LocalSaveService.instance.loadInto(restored);
    expect(restored.isMilestoneClaimed(5), isTrue);
    expect(restored.canClaimMilestone(5), isFalse);
  });
}
