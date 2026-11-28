import 'audio_service.dart';
import 'wizard_voice_stub.dart'
    if (dart.library.js_interop) 'wizard_voice_web.dart';

class WizardVoiceService {
  static final WizardVoiceService instance = WizardVoiceService._();
  WizardVoiceService._();

  bool enabled = false;

  void playWordBlip(int wordIndex) {
    if (!enabled || !SoundManager.instance.sfxEnabled) return;
    if (wordIndex == 0) {
      SoundManager.instance.playDogBark(isPuppy: true, force: true);
    }
    playWizardBlipImpl(
      volume: SoundManager.instance.sfxVolume.clamp(0.35, 1.0),
      wordIndex: wordIndex,
    );
  }

  void speak(
    String text, {
    void Function(int charIndex)? onBoundary,
    void Function()? onComplete,
  }) {
    if (!enabled || !SoundManager.instance.sfxEnabled) return;
    speakWizardTextImpl(
      text,
      volume: SoundManager.instance.sfxVolume.clamp(0.25, 1.0),
      onBoundary: onBoundary,
      onComplete: onComplete,
    );
  }

  void stop() {
    stopWizardSpeechImpl();
  }
}
