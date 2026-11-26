import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dogtopia/components/world/goals_dialog.dart';
import 'package:dogtopia/state/game_controller.dart';

void main() {
  testWidgets('Daily goals track actions and update to CLAIMED immediately',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final habitat = game.placedHabitats.firstWhere((h) => h.dogs.isNotEmpty);
    final dog = habitat.dogs.first;

    // Before feeding, task-1 shows 0/1 and cannot be claimed.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: GoalsDialog(game: game)),
    ));
    expect(find.text('0/1'), findsWidgets);
    expect(find.text('CLAIM'), findsNothing);

    // Feed a dog -> task-1 becomes ready and CLAIM appears live.
    final coinsBefore = game.coins;
    expect(game.feedDog(habitat.id, dog.id), isTrue);
    await tester.pump();
    expect(find.text('CLAIM'), findsOneWidget);

    // Tap CLAIM -> updates immediately to CLAIMED without reopening dialog.
    await tester.tap(find.text('CLAIM'));
    await tester.pump();
    expect(find.text('CLAIMED'), findsOneWidget);
    expect(game.coins, greaterThan(coinsBefore));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });
}
