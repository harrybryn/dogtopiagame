import 'package:flutter/material.dart';
import 'state/game_controller.dart';
import 'services/audio_service.dart';
import 'components/common/loading_screen.dart';
import 'components/common/walkthrough_overlay.dart';
import 'models/walkthrough_step.dart';
import 'pages/world_view_page.dart';
import 'pages/habitat_care_page.dart';
import 'pages/dog_factory_inside_page.dart';
import 'pages/breeding_page.dart';
import 'pages/collection_book_page.dart';
import 'models/habitat_model.dart';

void main() {
  runApp(const DogtopiaApp());
}

class DogtopiaApp extends StatelessWidget {
  const DogtopiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dogtopia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF120601),
        fontFamily: 'Fredoka',
        fontFamilyFallback: const ['Lilita One', 'Arial Rounded MT Bold', 'sans-serif'],
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          secondary: Color(0xFFEC4899),
          surface: Color(0xFF1F0B03),
        ),
      ),
      home: const DogtopiaRoot(),
    );
  }
}

class DogtopiaRoot extends StatefulWidget {
  const DogtopiaRoot({super.key});

  @override
  State<DogtopiaRoot> createState() => _DogtopiaRootState();
}

class _DogtopiaRootState extends State<DogtopiaRoot> {
  final GameController _game = GameController();
  final ValueNotifier<Rect?> _walkthroughWorldTargetRect =
      ValueNotifier<Rect?>(null);
  final Map<String, GlobalKey> _walkthroughKeys = {
    WalkthroughTargets.hudResources: GlobalKey(),
    WalkthroughTargets.hudCareDog: GlobalKey(),
    WalkthroughTargets.hudMakeFood: GlobalKey(),
    WalkthroughTargets.hudBuild: GlobalKey(),
    WalkthroughTargets.careDogStation: GlobalKey(),
    WalkthroughTargets.careFeedButton: GlobalKey(),
    WalkthroughTargets.careBackButton: GlobalKey(),
    WalkthroughTargets.factoryBakeButton: GlobalKey(),
    WalkthroughTargets.factorySpeedUpButton: GlobalKey(),
    WalkthroughTargets.factoryCollectButton: GlobalKey(),
    WalkthroughTargets.factoryBackButton: GlobalKey(),
  };
  bool _isLoading = true;
  String _currentRoute = 'world';
  Map<String, dynamic> _routeArgs = {};

  @override
  void initState() {
    super.initState();
    SoundManager.instance.init().then((_) {
      if (_game.bgmEnabled) {
        SoundManager.instance.startBgm();
      }
    });
  }

  void _navigateTo(String route, {Map<String, dynamic>? args}) {
    SoundManager.instance.playClick();
    setState(() {
      _currentRoute = route;
      _routeArgs = args ?? {};
    });
    _game.onWalkthroughRouteChanged(route);
  }

  @override
  void dispose() {
    _walkthroughWorldTargetRect.dispose();
    SoundManager.instance.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        SoundManager.instance.handleUserInteraction();
      },
      child: ListenableBuilder(
        listenable: _game,
        builder: (context, _) {
          if (_isLoading) {
            return LoadingScreen(
              duration: const Duration(milliseconds: 2600),
              onFinish: () {
                if (mounted) {
                  setState(() => _isLoading = false);
                  if (_game.bgmEnabled) {
                    SoundManager.instance.startBgm();
                  }
                  if (_game.walkthroughActive) {
                    SoundManager.instance.playWalkthroughPop();
                  }
                }
              },
            );
          }

          Widget activePage;
          switch (_currentRoute) {
            case 'factory':
              final habitat = _routeArgs['habitat'] as HabitatModel? ??
                  _game.placedHabitats.firstWhere((h) => h.isFactory,
                      orElse: () => HabitatModel.createDefaultDogfoodFactory());
              activePage = DogFactoryInsidePage(
                game: _game,
                habitat: habitat,
                onBackToWorld: () => _navigateTo('world'),
                walkthroughKeys: _walkthroughKeys,
              );
              break;

            case 'habitat':
              final habitat = _routeArgs['habitat'] as HabitatModel? ??
                  _game.placedHabitats.first;
              final initialDogIndex = _routeArgs['initialDogIndex'] as int? ?? 0;
              if (habitat.isFactory) {
                activePage = DogFactoryInsidePage(
                  game: _game,
                  habitat: habitat,
                  onBackToWorld: () => _navigateTo('world'),
                  walkthroughKeys: _walkthroughKeys,
                );
              } else {
                activePage = HabitatCarePage(
                  game: _game,
                  habitat: habitat,
                  initialDogIndex: initialDogIndex,
                  onBackToWorld: () => _navigateTo('world'),
                  onStartTransferDog: (dog, fromHabId) {
                    _navigateTo('world', args: {
                      'transferDog': dog,
                      'fromHabitatId': fromHabId,
                    });
                  },
                  walkthroughKeys: _walkthroughKeys,
                );
              }
              break;

            case 'breeding':
              activePage = BreedingPage(
                game: _game,
                onBackToWorld: () => _navigateTo('world'),
              );
              break;

            case 'collection':
              activePage = CollectionBookPage(
                onBackToWorld: () => _navigateTo('world'),
              );
              break;

            case 'world':
            default:
              activePage = WorldViewPage(
                game: _game,
                onNavigate: _navigateTo,
                initialArgs: _routeArgs,
                walkthroughKeys: _walkthroughKeys,
                worldTargetRectNotifier: _walkthroughWorldTargetRect,
              );
              break;
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              activePage,
              if (_game.walkthroughActive)
                WalkthroughOverlay(
                  game: _game,
                  currentRoute: _currentRoute,
                  targetKeys: _walkthroughKeys,
                  worldTargetRectNotifier: _walkthroughWorldTargetRect,
                  onReturnToWorld: () => _navigateTo('world'),
                ),
            ],
          );
        },
      ),
    );
  }
}
