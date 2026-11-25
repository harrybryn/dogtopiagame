import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogtopia/components/common/walkthrough_overlay.dart';
import 'package:dogtopia/models/food_recipe_model.dart';
import 'package:dogtopia/models/walkthrough_step.dart';
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

  test('Walkthrough advances through all 14 steps and grants reward once', () {
    final game = GameController();
    addTearDown(game.dispose);

    expect(game.walkthroughActive, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.welcome);

    // Step 1 -> 2 -> 3
    game.advanceWalkthrough();
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.hudTour);
    game.advanceWalkthrough();
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.selectGarden);

    // Step 3 -> 4: select starter garden
    game.selectHabitat('hab_starter_garden');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.enterHabitatCare);

    // Step 4 -> 5: enter habitat route
    game.onWalkthroughRouteChanged('habitat');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.feedDog);

    // Step 5 -> 6: feed Winston until Kibble runs out
    final firstFeed = game.feedDog('hab_starter_garden', 'dog_starter_bulldog');
    expect(firstFeed, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.feedDog);

    while (game.feedDog('hab_starter_garden', 'dog_starter_bulldog')) {
      // Keep feeding until out of kibble
    }
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.backFromHabitat);

    // Step 6 -> 7: return to world
    game.onWalkthroughRouteChanged('world');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.selectFactory);

    // Step 7 -> 8: select factory
    game.selectHabitat('hab_starter_factory');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.enterFactory);

    // Step 8 -> 9: enter factory route
    game.onWalkthroughRouteChanged('factory');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.bakeRecipe);

    // Step 9 -> 10: start baking first recipe
    final baked =
        game.startBakingFood('hab_starter_factory', FoodRecipeModel.recipes.first);
    expect(baked, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.speedUpBaking);

    // Step 10 -> 11: speed up baking with gems/crystals
    final spedUp = game.speedUpBaking('hab_starter_factory');
    expect(spedUp, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.collectKibble);

    // Step 11 -> 12: collect finished kibble
    final collected = game.collectDogfood('hab_starter_factory');
    expect(collected, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.backFromFactory);

    // Step 12 -> 13: return to world
    game.onWalkthroughRouteChanged('world');
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.shopAndGoals);

    // Step 13 -> 14: graduation
    game.advanceWalkthrough();
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.graduation);

    final coinsBefore = game.coins;
    final crystalsBefore = game.crystals;
    final xpBefore = game.xp;

    // Step 12: claim & finish
    game.advanceWalkthrough();
    expect(game.walkthroughActive, isFalse);
    expect(game.walkthroughRewardClaimed, isTrue);
    expect(game.coins, coinsBefore + 500);
    expect(game.crystals, crystalsBefore + 5);
    expect(game.xp, xpBefore + 100);

    // Replay should reset to step 1 and NOT double-grant reward
    game.restartWalkthrough();
    expect(game.walkthroughActive, isTrue);
    expect(game.currentWalkthroughStep?.id, WalkthroughStepId.welcome);
    while (game.walkthroughActive) {
      game.advanceWalkthrough();
    }
    expect(game.coins, coinsBefore + 500);
    expect(game.crystals, crystalsBefore + 5);
  });

  test('Walkthrough can be skipped at any step without granting reward', () {
    final game = GameController();
    addTearDown(game.dispose);

    final initialCoins = game.coins;
    game.skipWalkthrough();
    expect(game.walkthroughActive, isFalse);
    expect(game.walkthroughRewardClaimed, isFalse);
    expect(game.coins, initialCoins);
  });

  test('Steps 2 and 13 do not show an arrow', () {
    expect(
      WalkthroughStep.steps[1].id,
      WalkthroughStepId.hudTour,
    );
    expect(
      WalkthroughStep.steps[1].arrowDirection,
      WalkthroughArrowDirection.none,
    );
    expect(
      WalkthroughStep.steps[12].id,
      WalkthroughStepId.shopAndGoals,
    );
    expect(
      WalkthroughStep.steps[12].arrowDirection,
      WalkthroughArrowDirection.none,
    );
  });

  testWidgets('Welcome intro keeps only the X close button', (tester) async {
    final game = GameController();

    final worldTargetRect = ValueNotifier<Rect?>(null);
    addTearDown(worldTargetRect.dispose);

    await tester.pumpWidget(MaterialApp(
      home: ListenableBuilder(
        listenable: game,
        builder: (context, _) => Stack(
          children: [
            const SizedBox.expand(),
            WalkthroughOverlay(
              game: game,
              currentRoute: 'world',
              targetKeys: const {},
              worldTargetRectNotifier: worldTargetRect,
              onReturnToWorld: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('WELCOME TO DOGTOPIA!'), findsOneWidget);
    expect(find.text('SKIP TUTORIAL'), findsNothing);
    expect(
      find.image(
        const AssetImage(
          'assets/TrioUIKit_FreeSample_v2.2/png/1x/cozy/close_button.png',
        ),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });
}
