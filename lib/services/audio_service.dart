import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._internal();
  SoundManager._internal();

  static const String _prefBgmEnabled = 'dogtopia_bgm_enabled';
  static const String _prefBgmVolume = 'dogtopia_bgm_volume';
  static const String _prefSfxEnabled = 'dogtopia_sfx_enabled';
  static const String _prefSfxVolume = 'dogtopia_sfx_volume';

  bool sfxEnabled = true;
  bool bgmEnabled = true;

  double sfxVolume = 0.8;
  double bgmVolume = 0.5;
  bool hasSavedAudioPrefs = false;

  AudioPlayer _bgmPlayer = AudioPlayer();
  final List<AudioPlayer> _uiPool = List.generate(3, (_) => AudioPlayer());
  final List<AudioPlayer> _actionPool = List.generate(4, (_) => AudioPlayer());
  final List<AudioPlayer> _voicePool = List.generate(3, (_) => AudioPlayer());
  int _uiPoolIndex = 0;
  int _actionPoolIndex = 0;
  int _voicePoolIndex = 0;

  List<AudioPlayer> get _allSfxPlayers => [
        ..._uiPool,
        ..._actionPool,
        ..._voicePool,
      ];

  AudioPlayer _nextUiPlayer() {
    final player = _uiPool[_uiPoolIndex];
    _uiPoolIndex = (_uiPoolIndex + 1) % _uiPool.length;
    return player;
  }

  AudioPlayer _nextActionPlayer() {
    final player = _actionPool[_actionPoolIndex];
    _actionPoolIndex = (_actionPoolIndex + 1) % _actionPool.length;
    return player;
  }

  AudioPlayer _nextVoicePlayer() {
    final player = _voicePool[_voicePoolIndex];
    _voicePoolIndex = (_voicePoolIndex + 1) % _voicePool.length;
    return player;
  }

  final Random _rng = Random();
  int _lastHoverMs = 0;
  int _lastBarkMs = 0;
  bool _isBgmPlaying = false;
  bool _isStartingBgm = false;
  bool _prefsLoaded = false;
  bool _hasUserInteracted = !kIsWeb;
  int _bgmRequestId = 0;
  bool _bgmListenerAttached = false;

  void _attachBgmListener() {
    if (_bgmListenerAttached) return;
    _bgmListenerAttached = true;
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      _isBgmPlaying = state == PlayerState.playing;
    });
  }

  Future<void> init() async {
    _attachBgmListener();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefBgmEnabled) ||
          prefs.containsKey(_prefBgmVolume) ||
          prefs.containsKey(_prefSfxEnabled) ||
          prefs.containsKey(_prefSfxVolume)) {
        hasSavedAudioPrefs = true;
        bgmEnabled = prefs.getBool(_prefBgmEnabled) ?? bgmEnabled;
        bgmVolume = (prefs.getDouble(_prefBgmVolume) ?? bgmVolume).clamp(
          0.0,
          1.0,
        );
        sfxEnabled = prefs.getBool(_prefSfxEnabled) ?? sfxEnabled;
        sfxVolume = (prefs.getDouble(_prefSfxVolume) ?? sfxVolume).clamp(
          0.0,
          1.0,
        );
      }
    } catch (e) {
      debugPrint('SoundManager prefs load error: $e');
    } finally {
      _prefsLoaded = true;
    }

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmEnabled ? bgmVolume : 0.0);

      for (final p in _uiPool) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(sfxEnabled ? 0.5 * sfxVolume : 0.0);
      }

      for (final p in _actionPool) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(sfxEnabled ? 0.7 * sfxVolume : 0.0);
      }

      for (final p in _voicePool) {
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(sfxEnabled ? 0.65 * sfxVolume : 0.0);
      }

      if (!bgmEnabled || bgmVolume <= 0.001) {
        await stopBgm();
      }
    } catch (e) {
      debugPrint('SoundManager init error: $e');
    }
  }

  Future<void> _saveAudioPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBgmEnabled, bgmEnabled);
      await prefs.setDouble(_prefBgmVolume, bgmVolume);
      await prefs.setBool(_prefSfxEnabled, sfxEnabled);
      await prefs.setDouble(_prefSfxVolume, sfxVolume);
      hasSavedAudioPrefs = true;
    } catch (e) {
      debugPrint('SoundManager prefs save error: $e');
    }
  }

  /// Called on user interaction (e.g., tap/click anywhere on screen)
  /// to unlock Chrome/browser autoplay restrictions and start BGM if pending.
  void handleUserInteraction() {
    _hasUserInteracted = true;
    if (!_prefsLoaded) return;
    if (bgmEnabled &&
        bgmVolume > 0.001 &&
        !_isBgmPlaying &&
        !_isStartingBgm) {
      if (_bgmPlayer.state == PlayerState.paused) {
        resumeBgm();
      } else {
        startBgm();
      }
    }
  }

  // ──────────────────────────────────────────────
  // Background Music
  // ──────────────────────────────────────────────

  Future<void> startBgm() async {
    if (!_prefsLoaded || !bgmEnabled || bgmVolume <= 0.001) return;
    if (kIsWeb && !_hasUserInteracted) return;
    if (_isBgmPlaying || _isStartingBgm) return;
    final reqId = ++_bgmRequestId;
    _isStartingBgm = true;
    try {
      // Call play() first without prior awaits so Chrome/Web preserves the
      // synchronous user-gesture activation token for HTMLMediaElement.play().
      await _bgmPlayer.play(
        AssetSource('sounds/bgm.ogg', mimeType: 'audio/ogg'),
        volume: bgmVolume,
      );
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      if (!bgmEnabled || bgmVolume <= 0.001 || reqId != _bgmRequestId) {
        await _bgmPlayer.setVolume(0.0);
        await _bgmPlayer.pause();
        await _bgmPlayer.stop();
        _isBgmPlaying = false;
      } else {
        _isBgmPlaying = _bgmPlayer.state == PlayerState.playing;
      }
    } catch (e) {
      _isBgmPlaying = false;
      debugPrint('SoundManager BGM play error: $e');
      // Recreate player so a failed web autoplay attempt cannot wedge future plays.
      try {
        await _bgmPlayer.dispose();
      } catch (_) {}
      _bgmPlayer = AudioPlayer();
      _bgmListenerAttached = false;
      _attachBgmListener();
    } finally {
      _isStartingBgm = false;
    }
  }

  Future<void> stopBgm() async {
    _bgmRequestId++;
    _isBgmPlaying = false;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.stop);
      await _bgmPlayer.setVolume(0.0);
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('SoundManager stopBgm error: $e');
    }
  }

  Future<void> pauseBgm() async {
    _bgmRequestId++;
    _isBgmPlaying = false;
    try {
      await _bgmPlayer.pause();
    } catch (e) {
      debugPrint('SoundManager pauseBgm error: $e');
    }
  }

  Future<void> resumeBgm() async {
    if (!bgmEnabled) return;
    try {
      await _bgmPlayer.setVolume(bgmVolume);
      await _bgmPlayer.resume();
      _isBgmPlaying = true;
    } catch (_) {
      startBgm();
    }
  }

  void setBgmEnabled(bool enabled, {bool persist = true}) {
    bgmEnabled = enabled;
    if (persist) {
      _saveAudioPrefs();
    }
    if (bgmEnabled) {
      startBgm();
    } else {
      stopBgm();
    }
  }

  void setBgmVolume(double volume, {bool persist = true}) {
    bgmVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer.setVolume(bgmEnabled ? bgmVolume : 0.0);
    if (bgmEnabled && bgmVolume <= 0.001) {
      stopBgm();
    } else if (bgmEnabled && bgmVolume > 0.001 && !_isBgmPlaying) {
      startBgm();
    }
    if (persist) {
      _saveAudioPrefs();
    }
  }

  void setSfxEnabled(bool enabled, {bool persist = true}) {
    sfxEnabled = enabled;
    if (!sfxEnabled) {
      _stopAllSfx();
    }
    if (persist) {
      _saveAudioPrefs();
    }
  }

  void setSfxVolume(double volume, {bool persist = true}) {
    sfxVolume = volume.clamp(0.0, 1.0);
    if (sfxVolume <= 0.001) {
      _stopAllSfx();
    }
    if (persist) {
      _saveAudioPrefs();
    }
  }

  void _stopAllSfx() {
    for (final p in _allSfxPlayers) {
      p.setVolume(0.0).catchError((_) {});
      p.stop().catchError((_) {});
    }
  }

  // ──────────────────────────────────────────────
  // UI Sound Effects
  // ──────────────────────────────────────────────

  void playHover() {
    if (!sfxEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle hover to prevent audio stutter on fast mouse movement
    if (now - _lastHoverMs < 80) return;
    _lastHoverMs = now;

    _playFile(_nextUiPlayer(), 'sounds/hover.wav', volume: 0.25);
  }

  void playClick() {
    if (!sfxEnabled) return;
    _playFile(_nextUiPlayer(), 'sounds/click.wav', volume: 0.6);
  }

  // ──────────────────────────────────────────────
  // Gameplay Actions SFX
  // ──────────────────────────────────────────────

  void playFeed() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/feed.wav', volume: 0.8);
  }

  void playCollectCoins() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/coins.ogg', volume: 0.75);
  }

  void playCollectKibble() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/kibble.ogg', volume: 0.75);
  }

  void playBuild() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/build.ogg', volume: 0.85);
    _playFile(_nextActionPlayer(), 'sounds/build2.ogg', volume: 0.85);
  }

  void playBake() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/bake.ogg', volume: 0.8);
  }

  void playChop() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/chop.ogg', volume: 0.8);
  }

  void playPet() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/pet.ogg', volume: 0.7);
  }

  void playLevelUp() {
    if (!sfxEnabled) return;
    _playFile(_nextVoicePlayer(), 'sounds/level_up.ogg', volume: 0.9);
  }

  void playQuestReward() {
    if (!sfxEnabled) return;
    _playFile(_nextActionPlayer(), 'sounds/quest_reward.ogg', volume: 0.85);
  }

  void playSadWhimper() {
    if (!sfxEnabled) return;
    _playFile(_nextVoicePlayer(), 'sounds/sad_whimper.wav', volume: 0.6);
  }

  void playWalkthroughPop() {
    if (!sfxEnabled) return;
    _playFile(_nextVoicePlayer(), 'sounds/puppy_alert.wav', volume: 0.65);
  }

  void playWalkthroughStepComplete() {
    if (!sfxEnabled) return;
    _playFile(_nextVoicePlayer(), 'sounds/puppy_happy.wav', volume: 0.7);
  }

  void playDogBark({bool isPuppy = false, bool force = false}) {
    if (!sfxEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Don't play barks too rapidly unless forced
    if (!force && now - _lastBarkMs < 1200) return;
    _lastBarkMs = now;

    if (isPuppy) {
      final choice = _rng.nextBool();
      final sound = choice
          ? 'sounds/puppy_happy.wav'
          : 'sounds/puppy_alert.wav';
      _playFile(_nextVoicePlayer(), sound, volume: 0.7);
    } else {
      final choice = _rng.nextBool();
      final sound = choice ? 'sounds/dog_bark.ogg' : 'sounds/dog_bark_big.ogg';
      _playFile(_nextVoicePlayer(), sound, volume: 0.65);
    }
  }

  Future<void> _playFile(
    AudioPlayer player,
    String assetPath, {
    double volume = 1.0,
  }) async {
    if (!sfxEnabled || sfxVolume <= 0.001) return;
    try {
      final effectiveVolume = (volume * sfxVolume).clamp(0.0, 1.0);
      if (effectiveVolume <= 0.001) return;
      String? mimeType;
      if (assetPath.endsWith('.ogg')) {
        mimeType = 'audio/ogg';
      } else if (assetPath.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (assetPath.endsWith('.mp3')) {
        mimeType = 'audio/mpeg';
      }
      await player.play(
        AssetSource(assetPath, mimeType: mimeType),
        volume: effectiveVolume,
      );
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('AbortError')) {
        debugPrint('SoundManager _playFile error ($assetPath): $e');
      }
    }
  }

  void dispose() {
    _bgmPlayer.dispose();
    for (final p in _allSfxPlayers) {
      p.dispose();
    }
  }
}
