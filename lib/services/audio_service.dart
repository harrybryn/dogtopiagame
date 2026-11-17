import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager instance = SoundManager._internal();
  SoundManager._internal();

  bool sfxEnabled = true;
  bool bgmEnabled = true;

  double sfxVolume = 0.8;
  double bgmVolume = 0.5;

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer();
  final AudioPlayer _actionPlayer = AudioPlayer();
  final AudioPlayer _actionPlayer2 = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  final Random _rng = Random();
  int _lastHoverMs = 0;
  int _lastBarkMs = 0;
  bool _isBgmPlaying = false;

  Future<void> init() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(bgmVolume);

      await _uiPlayer.setReleaseMode(ReleaseMode.stop);
      await _uiPlayer.setVolume(0.5 * sfxVolume);

      await _actionPlayer.setReleaseMode(ReleaseMode.stop);
      await _actionPlayer.setVolume(0.7 * sfxVolume);

      await _actionPlayer2.setReleaseMode(ReleaseMode.stop);
      await _actionPlayer2.setVolume(0.7 * sfxVolume);

      await _voicePlayer.setReleaseMode(ReleaseMode.stop);
      await _voicePlayer.setVolume(0.65 * sfxVolume);
    } catch (e) {
      // Audio initialization fallback
    }
  }

  // ──────────────────────────────────────────────
  // Background Music
  // ──────────────────────────────────────────────

  Future<void> startBgm() async {
    if (!bgmEnabled) return;
    try {
      if (!_isBgmPlaying) {
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(bgmVolume);
        await _bgmPlayer.play(
          AssetSource('sounds/bgm.ogg', mimeType: 'audio/ogg'),
        );
        _isBgmPlaying = true;
      }
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _isBgmPlaying = false;
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
      _isBgmPlaying = false;
    } catch (_) {}
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

  void setBgmEnabled(bool enabled) {
    bgmEnabled = enabled;
    if (bgmEnabled) {
      startBgm();
    } else {
      pauseBgm();
    }
  }

  void setBgmVolume(double volume) {
    bgmVolume = volume.clamp(0.0, 1.0);
    _bgmPlayer.setVolume(bgmVolume);
  }

  void setSfxEnabled(bool enabled) {
    sfxEnabled = enabled;
  }

  void setSfxVolume(double volume) {
    sfxVolume = volume.clamp(0.0, 1.0);
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

    _playFile(_uiPlayer, 'sounds/hover.wav', volume: 0.25);
  }

  void playClick() {
    if (!sfxEnabled) return;
    _playFile(_uiPlayer, 'sounds/click.wav', volume: 0.6);
  }

  // ──────────────────────────────────────────────
  // Gameplay Actions SFX
  // ──────────────────────────────────────────────

  void playFeed() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/feed.wav', volume: 0.8);
  }

  void playCollectCoins() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/coins.ogg', volume: 0.75);
  }

  void playCollectKibble() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/kibble.ogg', volume: 0.75);
  }

  void playBuild() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/build.ogg', volume: 0.85);
    _playFile(_actionPlayer2, 'sounds/build2.ogg', volume: 0.85);
  }

  void playBake() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/bake.ogg', volume: 0.8);
  }

  void playChop() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/chop.ogg', volume: 0.8);
  }

  void playPet() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/pet.ogg', volume: 0.7);
  }

  void playLevelUp() {
    if (!sfxEnabled) return;
    _playFile(_voicePlayer, 'sounds/level_up.ogg', volume: 0.9);
  }

  void playQuestReward() {
    if (!sfxEnabled) return;
    _playFile(_actionPlayer, 'sounds/quest_reward.ogg', volume: 0.85);
  }

  void playSadWhimper() {
    if (!sfxEnabled) return;
    _playFile(_voicePlayer, 'sounds/sad_whimper.wav', volume: 0.6);
  }

  void playDogBark({bool isPuppy = false, bool force = false}) {
    if (!sfxEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Don't play barks too rapidly unless forced
    if (!force && now - _lastBarkMs < 1200) return;
    _lastBarkMs = now;

    if (isPuppy) {
      final choice = _rng.nextBool();
      final sound = choice ? 'sounds/puppy_happy.wav' : 'sounds/puppy_alert.wav';
      _playFile(_voicePlayer, sound, volume: 0.7);
    } else {
      final choice = _rng.nextBool();
      final sound = choice ? 'sounds/dog_bark.ogg' : 'sounds/dog_bark_big.ogg';
      _playFile(_voicePlayer, sound, volume: 0.65);
    }
  }

  Future<void> _playFile(AudioPlayer player, String assetPath, {double volume = 1.0}) async {
    try {
      await player.stop();
      await player.setVolume((volume * sfxVolume).clamp(0.0, 1.0));
      String? mimeType;
      if (assetPath.endsWith('.ogg')) {
        mimeType = 'audio/ogg';
      } else if (assetPath.endsWith('.wav')) {
        mimeType = 'audio/wav';
      } else if (assetPath.endsWith('.mp3')) {
        mimeType = 'audio/mpeg';
      }
      await player.play(AssetSource(assetPath, mimeType: mimeType));
    } catch (_) {}
  }

  void dispose() {
    _bgmPlayer.dispose();
    _uiPlayer.dispose();
    _actionPlayer.dispose();
    _actionPlayer2.dispose();
    _voicePlayer.dispose();
  }
}
