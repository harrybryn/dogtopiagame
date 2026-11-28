import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state/game_controller.dart';
import 'services/audio_service.dart';
import 'services/cloud_save_service.dart';
import 'services/local_save_service.dart';
import 'services/social_service.dart';
import 'components/common/existing_account_dialog.dart';
import 'components/common/loading_screen.dart';
import 'components/common/celebration_modal.dart';
import 'components/common/username_setup_overlay.dart';
import 'components/common/walkthrough_overlay.dart';
import 'models/walkthrough_step.dart';
import 'pages/world_view_page.dart';
import 'pages/habitat_care_page.dart';
import 'pages/dog_factory_inside_page.dart';
import 'pages/breeding_page.dart';
import 'pages/collection_book_page.dart';
import 'pages/friend_visit_page.dart';
import 'models/friend_visit_model.dart';
import 'models/habitat_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _enterLandscape();
  await CloudSaveService.instance.init();
  runApp(const DogtopiaApp());
}

/// Dogtopia is designed for landscape play. Lock phones/tablets to landscape
/// and use the full screen so the HUD never has to squeeze into portrait.
/// Web and desktop do not support this and simply keep their window size.
Future<void> _enterLandscape() async {
  try {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (_) {
    // Orientation locking is unavailable on some platforms (e.g. desktop/web).
  }
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
        fontFamilyFallback: const [
          'Lilita One',
          'Arial Rounded MT Bold',
          'sans-serif',
        ],
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

class _DogtopiaRootState extends State<DogtopiaRoot>
    with WidgetsBindingObserver {
  final GameController _game = GameController();
  final Map<String, MockFriend> _mockFriendsById = {
    for (final f in MockFriend.allFriends()) f.id: f,
  };
  MockFriend _resolveMockFriend(MockFriend? arg) {
    if (arg == null) return _mockFriendsById.values.first;
    return _mockFriendsById.putIfAbsent(arg.id, () => arg);
  }
  final ValueNotifier<Rect?> _walkthroughWorldTargetRect = ValueNotifier<Rect?>(
    null,
  );
  final Map<String, GlobalKey> _walkthroughKeys = {
    WalkthroughTargets.hudResources: GlobalKey(),
    WalkthroughTargets.hudCareDog: GlobalKey(),
    WalkthroughTargets.hudMakeFood: GlobalKey(),
    WalkthroughTargets.hudBuild: GlobalKey(),
    WalkthroughTargets.hudIslands: GlobalKey(),
    WalkthroughTargets.hudSocial: GlobalKey(),
    WalkthroughTargets.careDogStation: GlobalKey(),
    WalkthroughTargets.careFeedButton: GlobalKey(),
    WalkthroughTargets.careBathButton: GlobalKey(),
    WalkthroughTargets.careBackButton: GlobalKey(),
    WalkthroughTargets.factoryBakeButton: GlobalKey(),
    WalkthroughTargets.factorySpeedUpButton: GlobalKey(),
    WalkthroughTargets.factoryCollectButton: GlobalKey(),
    WalkthroughTargets.factoryBackButton: GlobalKey(),
  };
  bool _isLoading = true;
  bool _saveHydrated = false;
  bool _pendingCloudSync = false;
  String? _giftBannerMessage;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<String>? _giftSub;
  String _currentRoute = 'world';
  Map<String, dynamic> _routeArgs = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game.addListener(_onGameStateChanged);

    _giftSub = SocialService.instance.onGiftNotification.listen((msg) {
      if (!mounted) return;
      SoundManager.instance.playQuestReward();
      setState(() => _giftBannerMessage = msg);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _giftBannerMessage == msg) {
          setState(() => _giftBannerMessage = null);
        }
      });
    });

    _authSub = CloudSaveService.instance.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedOut) {
        await SocialService.instance.stopRealtime();
        return;
      }
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        if (_saveHydrated) {
          final status = await CloudSaveService.instance.syncOnLogin(_game);
          _handleExistingAccountPromptIfNeeded(status);
          SocialService.instance.startRealtime(_game);
        } else {
          _pendingCloudSync = true;
        }
      }
    });

    _initServices();
  }

  void _handleExistingAccountPromptIfNeeded(CloudSyncStatus status) {
    final pending = CloudSaveService.instance.pendingExistingAccount;
    if (status == CloudSyncStatus.accountAlreadyExists &&
        pending != null &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showExistingGoogleAccountDialog(context, _game, pending);
        }
      });
    } else if (status == CloudSyncStatus.noCloudAccountFound && mounted) {
      final email =
          CloudSaveService.instance.userEmail ?? 'This Google account';
      final wasSwitch = CloudSaveService.instance.lastSyncWasSwitch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (wasSwitch) {
          showNoCloudAccountDialog(context, email);
        } else {
          showBindEmptyGoogleAccountDialog(context, _game, email);
        }
      });
    }
  }

  Future<void> _initServices() async {
    await SoundManager.instance.init();
    if (!mounted) return;
    _game.syncAudioFromSoundManager();
    if (_game.bgmEnabled) {
      SoundManager.instance.startBgm();
    }
    await LocalSaveService.instance.loadInto(_game);
    if (!mounted) return;
    if (CloudSaveService.instance.isSignedIn || _pendingCloudSync) {
      _pendingCloudSync = false;
      final status = await CloudSaveService.instance.syncOnLogin(_game);
      _handleExistingAccountPromptIfNeeded(status);
      SocialService.instance.startRealtime(_game);
    }
    if (!mounted) return;
    _game.syncAudioFromSoundManager();
    setState(() => _saveHydrated = true);
  }

  void _onGameStateChanged() {
    if (_saveHydrated && _game.hasUsername) {
      LocalSaveService.instance.scheduleAutoSave(_game);
      CloudSaveService.instance.scheduleAutoSave(_game);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_saveHydrated &&
        _game.hasUsername &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.detached)) {
      LocalSaveService.instance.saveNow(_game);
      CloudSaveService.instance.saveNow(_game);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _giftSub?.cancel();
    SocialService.instance.stopRealtime();
    _game.removeListener(_onGameStateChanged);
    if (_saveHydrated && _game.hasUsername) {
      LocalSaveService.instance.saveNow(_game);
      CloudSaveService.instance.saveNow(_game);
    } else {
      LocalSaveService.instance.cancelPending();
      CloudSaveService.instance.cancelPending();
    }
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
      onPointerUp: (_) {
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
                  if (_game.hasUsername && _game.walkthroughActive) {
                    SoundManager.instance.playWalkthroughPop();
                  }
                }
              },
            );
          }

          Widget activePage;
          switch (_currentRoute) {
            case 'factory':
              final habitat =
                  _routeArgs['habitat'] as HabitatModel? ??
                  _game.placedHabitats.firstWhere(
                    (h) => h.isFactory,
                    orElse: () => HabitatModel.createDefaultDogfoodFactory(),
                  );
              activePage = DogFactoryInsidePage(
                game: _game,
                habitat: habitat,
                onBackToWorld: () => _navigateTo('world'),
                walkthroughKeys: _walkthroughKeys,
              );
              break;

            case 'habitat':
              final habitat =
                  _routeArgs['habitat'] as HabitatModel? ??
                  _game.placedHabitats.first;
              final initialDogIndex =
                  _routeArgs['initialDogIndex'] as int? ?? 0;
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
                    _navigateTo(
                      'world',
                      args: {'transferDog': dog, 'fromHabitatId': fromHabId},
                    );
                  },
                  walkthroughKeys: _walkthroughKeys,
                );
              }
              break;

            case 'breeding':
              activePage = BreedingPage(
                game: _game,
                onBackToWorld: () => _navigateTo('world'),
                onStartPlaceBredPuppy: (breedId, breedName, element, sitImg) {
                  _navigateTo(
                    'world',
                    args: {
                      'placeBredPuppy': {
                        'breedId': breedId,
                        'breedName': breedName,
                        'element': element,
                        'sitImg': sitImg,
                      },
                    },
                  );
                },
              );
              break;

            case 'collection':
              activePage = CollectionBookPage(
                onBackToWorld: () => _navigateTo('world'),
              );
              break;

            case 'friend_visit':
              final friend =
                  _resolveMockFriend(_routeArgs['friend'] as MockFriend?);
              final initialIslandId = _routeArgs['islandId'] as String?;
              final showOverview =
                  _routeArgs['showOverview'] as bool? ?? false;
              activePage = FriendVisitPage(
                game: _game,
                friend: friend,
                initialIslandId: initialIslandId,
                initialShowOverview: showOverview,
                onBackToWorld: () => _navigateTo('world'),
                onOpenHabitat: (habitat) => _navigateTo(
                  'friend_habitat',
                  args: {
                    'habitat': habitat,
                    'friend': friend,
                    'islandId': habitat.islandId,
                  },
                ),
              );
              break;

            case 'friend_habitat':
              final friend =
                  _resolveMockFriend(_routeArgs['friend'] as MockFriend?);
              final habitat = _routeArgs['habitat'] as HabitatModel? ??
                  friend.habitats.first;
              activePage = HabitatCarePage(
                game: _game,
                habitat: habitat,
                isVisitMode: true,
                visitFriend: friend,
                onBackToWorld: () => _navigateTo(
                  'friend_visit',
                  args: {'friend': friend, 'islandId': habitat.islandId},
                ),
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
              if (!_game.hasUsername)
                UsernameSetupOverlay(
                  onConfirmUsername: (name) {
                    _game.setUsername(name);
                    LocalSaveService.instance.saveNow(_game);
                    CloudSaveService.instance.saveNow(_game);
                    if (_game.walkthroughActive) {
                      SoundManager.instance.playWalkthroughPop();
                    }
                  },
                  onLoginExistingAccount: () async {
                    final ok = await CloudSaveService.instance.signInWithGoogle(
                      preferCloud: true,
                    );
                    if (!ok) {
                      return 'Google sign-in was cancelled or failed.';
                    }
                    if (CloudSaveService.instance.isSignedIn) {
                      final status = await CloudSaveService.instance.syncOnLogin(
                        _game,
                        preferCloud: true,
                      );
                      if (status == CloudSyncStatus.loadedFromCloud) {
                        await LocalSaveService.instance.saveNow(_game);
                        return null;
                      }
                      if (status == CloudSyncStatus.noCloudAccountFound) {
                        if (!mounted) return null;
                        final email = CloudSaveService.instance.userEmail ??
                            'This Google account';
                        final bound = await showBindEmptyGoogleAccountDialog(
                          context,
                          _game,
                          email,
                        );
                        return bound
                            ? 'Google account connected! Enter a username to start & save.'
                            : 'Cancelled. Not connected to Google.';
                      }
                      if (status == CloudSyncStatus.failed) {
                        return CloudSaveService.instance.lastError ??
                            'Failed to load cloud account.';
                      }
                      return 'Signed in, but no saved island was found. Enter a username to start!';
                    }
                    return null;
                  },
                )
              else if (_game.walkthroughActive)
                WalkthroughOverlay(
                  game: _game,
                  currentRoute: _currentRoute,
                  targetKeys: _walkthroughKeys,
                  worldTargetRectNotifier: _walkthroughWorldTargetRect,
                  onReturnToWorld: () => _navigateTo('world'),
                ),
              if (_game.hasUsername && _game.currentCelebration != null)
                CelebrationModal(
                  event: _game.currentCelebration!,
                  onDismiss: _game.dismissCelebration,
                ),
              if (_giftBannerMessage != null)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFEF08A), width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x88000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.card_giftcard_rounded,
                                color: Color(0xFFFEF08A), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _giftBannerMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 13.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
