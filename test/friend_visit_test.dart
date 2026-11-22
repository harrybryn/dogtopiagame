import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dogtopia/components/world/social_dialog.dart';
import 'package:dogtopia/components/world/world_isometric_grid.dart';
import 'package:dogtopia/models/dog_evolution.dart';
import 'package:dogtopia/models/friend_visit_model.dart';
import 'package:dogtopia/pages/friend_visit_page.dart';
import 'package:dogtopia/pages/habitat_care_page.dart';
import 'package:dogtopia/state/game_controller.dart';

void main() {
  testWidgets('Social dialog has one visit-island action', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var visited = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SocialDialog(
          onVisit: () => visited = true,
        ),
      ),
    ));

    expect(find.text('COMMUNITY & FRIENDS'), findsOneWidget);
    expect(find.text('VISIT ISLAND'), findsOneWidget);

    await tester.tap(find.text('VISIT ISLAND'));
    expect(visited, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Friend visit fits 640x360', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final friend = MockFriend.sample();

    await tester.pumpWidget(MaterialApp(
      home: FriendVisitPage(
        game: game,
        friend: friend,
        onBackToWorld: () {},
        onOpenHabitat: (_) {},
      ),
    ));
    await tester.pump();

    expect(find.textContaining('VISITING ALEX'), findsOneWidget);
    expect(find.byType(WorldIsometricGrid), findsOneWidget);
    expect(find.textContaining('HELP'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('Friend habitat opens the normal care flow, help only',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final friend = MockFriend.sample();

    final ownHabitatCount = game.placedHabitats.length;
    final ownDog = game.placedHabitats
        .firstWhere((habitat) => habitat.dogs.isNotEmpty)
        .dogs
        .first;
    final ownDogName = ownDog.name;
    final ownDogLevel = ownDog.level;
    final ownDogFeedProgress = ownDog.feedProgress;
    final kibbleBefore = game.kibble;
    final coinsBefore = game.coins;

    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: FriendVisitPage(
        game: game,
        friend: friend,
        onBackToWorld: () {},
        onOpenHabitat: (habitat) => opened.add(habitat.id),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('VISITING ALEX'), findsOneWidget);
    final grid = tester.widget<WorldIsometricGrid>(
      find.byType(WorldIsometricGrid),
    );
    expect(grid.habitats.length, greaterThanOrEqualTo(5));
    expect(grid.habitats.map((h) => h.name), contains('Sunny Garden'));

    // Tapping a pet on the island opens its habitat, just like your own world.
    await tester.tap(
      find.byKey(const ValueKey('friend_garden_dog_friend_dog_golden_0')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(opened, contains('friend_garden'));

    final friendHabitat = friend.habitats
        .firstWhere((habitat) => habitat.id == opened.first);
    await tester.pumpWidget(MaterialApp(
      home: HabitatCarePage(
        game: game,
        habitat: friendHabitat,
        isVisitMode: true,
        visitFriend: friend,
        onBackToWorld: () {},
      ),
    ));
    await tester.pump();

    final friendDog = friend.dogs.first;
    final feedProgressBefore = friendDog.feedProgress;
    final levelBefore = friendDog.level;

    expect(find.text('SUNNY'), findsWidgets);
    expect(find.textContaining('SELL'), findsNothing);
    expect(find.textContaining('TRANSFER'), findsNothing);
    expect(find.textContaining('RENAME'), findsNothing);
    expect(find.textContaining('COLLECT'), findsNothing);
    expect(find.textContaining('HELP'), findsNothing);

    await tester.tap(find.byKey(const Key('friend_pet_dog')));
    await tester.pump();
    expect(friend.helpCount, 1);
    expect(game.coins, coinsBefore);

    final cost = DogStageInfo.getInfo(friendDog).kibbleCostPerFeed;
    await tester.tap(find.text('FEED'));
    await tester.pump();
    expect(game.kibble, kibbleBefore - cost);
    expect(friendDog.feedProgress, feedProgressBefore + 1);
    expect(friend.helpCount, 2);

    await tester.tap(find.text('FEED'));
    await tester.pump();
    expect(friendDog.level, levelBefore + 1);
    expect(friendDog.feedProgress, 0);

    expect(game.placedHabitats.length, ownHabitatCount);
    expect(ownDog.name, ownDogName);
    expect(ownDog.level, ownDogLevel);
    expect(ownDog.feedProgress, ownDogFeedProgress);

    // Let the care-page toast/heart timers finish before the test ends.
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });
}
