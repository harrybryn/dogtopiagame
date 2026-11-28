# AGENTS.md

## Working rules
- Never scan the whole project. Use the folder map below to find relevant files, then search before opening anything.
- Read only files needed for the current task.
- Make targeted edits; don't rewrite whole files.
- Don't re-read files already seen in this conversation.
- If unsure where something lives, search or ask. Don't explore.
- Keep replies short. Don't repeat my code back or give long explanations unless asked.
- Detailed docs live in `/docs`. Read them only when the task needs them.
- After finishing, tell me if any part of this file is now outdated.

## 1. Project Purpose
- Cross-platform Flutter pet-sim / isometric island-builder game ("Dogtopia", Dragon City-style).
- Players build habitats, facilities (Dogfood Factory, Breeding Den), and decor on an isometric grid, clear obstacles, unlock expansion lots, bake kibble, and raise/evolve/breed dogs.
- Pure client-side in-memory simulation with no backend or local save persistence yet.

## 2. Tech Stack & Versions
- Flutter (`stable` channel), Dart SDK `^3.10.7`, package `dogtopia` `1.0.0+1`.
- Runtime dependencies: `flutter`, `cupertino_icons: ^1.0.8`, `audioplayers: ^6.0.0`.
- Dependency overrides: `path_provider_foundation: 2.4.4`, `path_provider_android: 2.2.10`.
- Dev dependencies: `flutter_test`, `flutter_lints: ^6.0.0`.
- Fonts: `Fredoka` (default), `Lilita One`; targets: Android, iOS, Web, Windows, macOS, Linux.

## 3. Folder Map
- `lib/` — Application Dart source (`main.dart` + feature folders).
- `lib/state/` — Root `ChangeNotifier` game state and loop (`GameController`).
- `lib/models/` — Mutable domain models and static catalogs (dogs, habitats, recipes, obstacles, tasks).
- `lib/pages/` — Top-level full-screen views swapped by route string.
- `lib/components/world/` — Isometric grid, HUD, wandering dog sprites, and world modal dialogs.
- `lib/components/common/` — Shared UI widgets (modal frame, hover scale, loading screen/bar).
- `lib/services/` — Singleton `SoundManager` audio service.
- `lib/assets/` — Unused legacy asset tree (leftover Vite/React files; not registered in `pubspec.yaml`).
- `assets/` — Active bundled runtime assets (UI, dogs, habitats, buildings, shop icons, sounds, fonts, TrioUIKit).
- `test/` — Flutter widget tests.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` — Standard Flutter platform runners.

## 4. Key Files
- `lib/main.dart` — Entry point (`DogtopiaApp`, `DogtopiaRoot`), dark theme, string route switcher (`world`, `habitat`, `factory`, `breeding`, `collection`).
- `lib/state/game_controller.dart` — Single source of truth: currencies (`coins`, `crystals`, `kibble`), XP/level, lot unlocks, habitats, obstacles, tasks, 10s income/baking timer.
- `lib/services/audio_service.dart` — `SoundManager.instance` multi-channel `AudioPlayer` wrapper (BGM + UI/action/voice SFX).
- `lib/models/habitat_model.dart` — Core placed-entity schema (`habitat` | `facility` | `decor`, construction & baking timers, coin/dogfood storage).
- `lib/models/dog_model.dart` & `lib/models/dog_evolution.dart` — Dog entities, levels, and evolution stage rules.
- `lib/models/habitat_catalog.dart` & `lib/models/food_recipe_model.dart` — Static shop items and baking recipes.
- `pubspec.yaml` & `analysis_options.yaml` — Dependencies, asset/font declarations, and `flutter_lints` config.
- DB / persistence schema — None (in-memory only).

## 5. Architecture & Data Flow
- Single `GameController` (`ChangeNotifier`) created in `_DogtopiaRootState` and passed down via constructor props (no Provider/Riverpod/Bloc).
- `ListenableBuilder` at root rebuilds the active page whenever `GameController.notifyListeners()` fires.
- Navigation is imperative state switching (`_navigateTo(route, args: {...})`), not `Navigator` named routes; overlays use `showDialog`.
- `Timer.periodic(10s)` calls `GameController.tickIncome()` to accumulate habitat coins and complete factory baking using epoch ms (`DateTime.now().millisecondsSinceEpoch`).
- Mutations live in `GameController`: mutate model fields in place, play SFX via `SoundManager.instance`, call `notifyListeners()`, return `bool` for validation/cost checks.
- Root translucent `Listener` calls `SoundManager.instance.handleUserInteraction()` to unlock browser BGM autoplay.

## 6. Conventions
- Naming: `snake_case.dart` files; `PascalCase` classes; role suffixes `*_page.dart`, `*_dialog.dart`, `*_model.dart`, `*_service.dart`.
- State: Mutable models mutated directly by `GameController`, followed by `notifyListeners()`.
- Error handling: Guarded mutations return `bool` (`false` + `playSadWhimper()` on insufficient currency); missing items handled via `firstWhere(..., orElse: () => emptySentinel)` or `try/catch` returning `null`; audio errors caught and logged with `debugPrint`.
- Linting: `package:flutter_lints/flutter.yaml`; `build/**` and platform directories excluded.
- Testing: Currently smoke-test only (`test/widget_test.dart`); add unit tests for `GameController` logic and widget tests under `test/`.

## 7. Commands
- Install dependencies: `flutter pub get`
- Run app: `flutter run` (e.g., `flutter run -d chrome`, `flutter run -d windows`)
- Build: `flutter build web` | `flutter build apk` | `flutter build windows`
- Test: `flutter test`
- Lint / analyze: `flutter analyze`

## 8. Gotchas
- No save persistence or backend: all game state resets on restart; no required env variables.
- Ignore `lib/assets/` (unused legacy copy); add/reference assets strictly under root `assets/` and register new directories in `pubspec.yaml`.
- Keep `dependency_overrides` (`path_provider_foundation`, `path_provider_android`) in `pubspec.yaml` unless re-verifying `audioplayers` builds.
- `DogtopiaRoot` runs a 2.6s `LoadingScreen` on launch, and `GameController` starts an active 10s `Timer.periodic` in its constructor — dispose controllers/advance timers properly in widget tests.
- `CollectionBookPage` is instantiated without `game` in `lib/main.dart` (not wired to live `GameController` state).
- Lot unlock boundaries are hardcoded in `GameController.isTileUnlocked(col, row)`: `row >= 11` always open, `col < 13 && row < 11` = Lot 1, remainder = Lot 2.
- Do not manually edit `.metadata` or generated platform runner files unless changing native config.

## 9. Where to Look
- Entry, theme, routing -> `lib/main.dart`
- Economy, XP, lots, income tick -> `lib/state/game_controller.dart`
- Isometric grid & world map -> `lib/components/world/world_isometric_grid.dart`, `lib/pages/world_view_page.dart`
- HUD & world dialogs (shop, goals, progress, ranking, settings, social, info) -> `lib/components/world/`
- Habitat interior & dog care -> `lib/pages/habitat_care_page.dart`, `lib/components/world/habitat_wandering_dog.dart`
- Dogfood factory & recipes -> `lib/pages/dog_factory_inside_page.dart`, `lib/models/food_recipe_model.dart`
- Breeding & collection book -> `lib/pages/breeding_page.dart`, `lib/pages/collection_book_page.dart`
- Dog models & evolution -> `lib/models/dog_model.dart`, `lib/models/dog_evolution.dart`
- Building/habitat catalog & models -> `lib/models/habitat_catalog.dart`, `lib/models/habitat_model.dart`
- Obstacles & tasks -> `lib/models/obstacle_model.dart`, `lib/models/task_model.dart`
- Audio (BGM/SFX) -> `lib/services/audio_service.dart`
- Shared UI primitives -> `lib/components/common/`

## 10. Detailed Docs (`/docs`)
- No `/docs` directory exists yet (`README.md` is the default Flutter starter template).
- When detailed docs are added under `/docs`, list them here and read them only when working on that specific subsystem.
