import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogtopia/state/game_controller.dart';
import 'package:dogtopia/pages/world_view_page.dart';
import 'package:dogtopia/pages/habitat_care_page.dart';
import 'package:dogtopia/pages/dog_factory_inside_page.dart';
import 'package:dogtopia/components/world/goals_dialog.dart';
import 'package:dogtopia/components/world/progress_dialog.dart';
import 'package:dogtopia/components/world/social_dialog.dart';
import 'package:dogtopia/components/world/ranking_dialog.dart';
import 'package:dogtopia/components/world/settings_dialog.dart';
import 'package:dogtopia/components/world/habitat_info_dialog.dart';
import 'package:dogtopia/components/world/build_shop_dialog.dart';
import 'package:dogtopia/components/common/hover_scale.dart';
import 'package:dogtopia/models/food_recipe_model.dart';

const _sizes = <Size>[
  Size(640, 360), // small phone, landscape
  Size(740, 383), // short desktop window
  Size(839, 542), // laptop-ish window
  Size(1280, 720), // full landscape
  Size(400, 800), // portrait fallback (web/desktop window)
];

Future<void> _pumpPage(WidgetTester tester, Size size, Widget page) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pump(const Duration(milliseconds: 120));

  expect(
    tester.takeException(),
    isNull,
    reason: 'Layout threw at $size',
  );

  // Tear the page down so its timers are cancelled.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  testWidgets('Dog name clears the resource pills at 640x360', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final habitat = game.placedHabitats.firstWhere((h) => h.dogs.isNotEmpty);
    await tester.pumpWidget(MaterialApp(
      home: HabitatCarePage(
        game: game,
        habitat: habitat,
        onBackToWorld: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    final nameRect =
        tester.getRect(find.text(habitat.dogs.first.name.toUpperCase()));
    for (final label in ['${game.crystals}', '5.0 K', '1.0 K']) {
      final pillRect = tester.getRect(find.text(label));
      expect(
        nameRect.top >= pillRect.bottom ||
            nameRect.bottom <= pillRect.top ||
            nameRect.right <= pillRect.left ||
            nameRect.left >= pillRect.right,
        isTrue,
        reason: 'Dog name overlaps resource "$label" at 640x360',
      );
    }

    // The dog stage stays side-by-side and fits without a scroll view.
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('Bakery shows that more recipes are below at 640x360',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final factory = game.placedHabitats.firstWhere((h) => h.isFactory);
    await tester.pumpWidget(MaterialApp(
      home: DogFactoryInsidePage(
        game: game,
        habitat: factory,
        onBackToWorld: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byType(Scrollbar), findsWidgets);
    expect(find.text('MORE RECIPES BELOW'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('Shop categories keep art and details visible at 640x360',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    await tester.pumpWidget(MaterialApp(
      home: BuildShopDialog(
        game: game,
        onSelectBuildingToPlace: (_) {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('HABITATS'), findsOneWidget);
    expect(find.text('Star Crystals & Paw Coins'), findsOneWidget);

    final habitatIcon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/ui/HabitatShopIcon.png',
    );
    expect(habitatIcon, findsOneWidget);
    expect(tester.getRect(habitatIcon).height, greaterThan(25));

    final background = tester.getRect(find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/ui/ShopModal.webp',
    ));
    final card = tester.getRect(
      find.ancestor(
        of: find.text('HABITATS'),
        matching: find.byType(HoverScale),
      ).first,
    );
    expect(card.left, greaterThanOrEqualTo(background.left));
    expect(card.right, lessThanOrEqualTo(background.right));
    expect(card.top, greaterThanOrEqualTo(background.top));
    expect(card.bottom, lessThanOrEqualTo(background.bottom));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('Shop item cards keep art and details visible at 640x360',
      (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    await tester.pumpWidget(MaterialApp(
      home: BuildShopDialog(
        game: game,
        onSelectBuildingToPlace: (_) {},
        initialTab: 'habitats',
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    final itemArt = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('assets/habitats/'),
    );
    expect(itemArt, findsWidgets);
    expect(tester.getRect(itemArt.first).height, greaterThan(25));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('Baking in oven panel fits at 640x360', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final factory = game.placedHabitats.firstWhere((h) => h.isFactory);
    expect(game.startBakingFood(factory.id, FoodRecipeModel.recipes.first), isTrue);

    await tester.pumpWidget(MaterialApp(
      home: DogFactoryInsidePage(
        game: game,
        habitat: factory,
        onBackToWorld: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('BAKING IN OVEN'), findsOneWidget);
    expect(find.byType(FittedBox), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('World dialogs fit at 640x360', (tester) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final game = GameController(startWalkthrough: false);
    final dialogs = <Widget>[
      GoalsDialog(game: game),
      ProgressDialog(game: game),
      SocialDialog(),
      RankingDialog(),
      SettingsDialog(game: game),
      HabitatInfoDialog(
        habitat: game.placedHabitats.first,
        onOpenCare: (_) {},
      ),
    ];

    for (final dialog in dialogs) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.takeException(),
        isNull,
        reason: '${dialog.runtimeType} threw at 640x360',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
    game.dispose();
  });

  for (final size in _sizes) {
    testWidgets('World view fits at $size', (tester) async {
      final game = GameController(startWalkthrough: false);
      await _pumpPage(
        tester,
        size,
        WorldViewPage(game: game, onNavigate: (route, {args}) {}),
      );
      game.dispose();
    });

    testWidgets('Selected habitat bar fits at $size', (tester) async {
      final game = GameController(startWalkthrough: false);
      final habitat = game.placedHabitats.firstWhere((h) => !h.isFactory);
      game.selectHabitat(habitat.id);
      await _pumpPage(
        tester,
        size,
        WorldViewPage(game: game, onNavigate: (route, {args}) {}),
      );
      game.dispose();
    });

    testWidgets('Habitat care fits at $size', (tester) async {
      final game = GameController(startWalkthrough: false);
      final habitat = game.placedHabitats.firstWhere((h) => !h.isFactory);
      await _pumpPage(
        tester,
        size,
        HabitatCarePage(
          game: game,
          habitat: habitat,
          onBackToWorld: () {},
        ),
      );
      game.dispose();
    });

    testWidgets('Kibble bakery fits at $size', (tester) async {
      final game = GameController(startWalkthrough: false);
      final factory = game.placedHabitats.firstWhere((h) => h.isFactory);
      await _pumpPage(
        tester,
        size,
        DogFactoryInsidePage(
          game: game,
          habitat: factory,
          onBackToWorld: () {},
        ),
      );
      game.dispose();
    });
  }
}
