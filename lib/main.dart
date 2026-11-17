import 'package:flutter/material.dart';
import 'state/game_controller.dart';
import 'services/audio_service.dart';
import 'components/common/loading_screen.dart';
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
  }

  @override
  void dispose() {
    SoundManager.instance.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
              }
            },
          );
        }

        switch (_currentRoute) {
          case 'factory':
            final habitat = _routeArgs['habitat'] as HabitatModel? ??
                _game.placedHabitats.firstWhere((h) => h.isFactory,
                    orElse: () => HabitatModel.createDefaultDogfoodFactory());
            return DogFactoryInsidePage(
              game: _game,
              habitat: habitat,
              onBackToWorld: () => _navigateTo('world'),
            );

          case 'habitat':
            final habitat = _routeArgs['habitat'] as HabitatModel? ??
                _game.placedHabitats.first;
            if (habitat.isFactory) {
              return DogFactoryInsidePage(
                game: _game,
                habitat: habitat,
                onBackToWorld: () => _navigateTo('world'),
              );
            }
            return HabitatCarePage(
              game: _game,
              habitat: habitat,
              onBackToWorld: () => _navigateTo('world'),
              onStartTransferDog: (dog, fromHabId) {
                _navigateTo('world', args: {
                  'transferDog': dog,
                  'fromHabitatId': fromHabId,
                });
              },
            );

          case 'breeding':
            return BreedingPage(
              game: _game,
              onBackToWorld: () => _navigateTo('world'),
            );

          case 'collection':
            return CollectionBookPage(
              onBackToWorld: () => _navigateTo('world'),
            );

          case 'world':
          default:
            return WorldViewPage(
              game: _game,
              onNavigate: _navigateTo,
              initialArgs: _routeArgs,
            );
        }
      },
    );
  }
}
