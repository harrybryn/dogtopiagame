import 'dart:js_interop';
import 'dart:js_interop_unsafe';

typedef WordBoundaryCallback = void Function(int charIndex);

@JS('window.speechSynthesis')
external JSObject? get _speechSynthesis;

@JS('SpeechSynthesisUtterance')
extension type _SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external factory _SpeechSynthesisUtterance(String text);
  external set rate(double value);
  external set pitch(double value);
  external set volume(double value);
  external set lang(String value);
  external set voice(JSObject? value);
  external set onboundary(JSFunction? value);
  external set onend(JSFunction? value);
  external set onerror(JSFunction? value);
}

JSObject? _pickWizardVoice(JSObject synth) {
  try {
    final rawVoices = synth.callMethod<JSArray<JSObject>>('getVoices'.toJS);
    final voices = rawVoices.toDart;
    if (voices.isEmpty) return null;

    // Prefer natural, expressive voices over robotic legacy SAPI voices
    const preferredNames = [
      'natural',
      'google us english',
      'microsoft aria',
      'microsoft jenny',
      'microsoft guy',
      'samantha',
      'karen',
      'daniel',
    ];

    for (final target in preferredNames) {
      for (final v in voices) {
        final name = (v.getProperty<JSString?>('name'.toJS)?.toDart ?? '')
            .toLowerCase();
        final lang = (v.getProperty<JSString?>('lang'.toJS)?.toDart ?? '')
            .toLowerCase();
        if (lang.startsWith('en') && name.contains(target)) return v;
      }
    }

    for (final v in voices) {
      final lang = (v.getProperty<JSString?>('lang'.toJS)?.toDart ?? '')
          .toLowerCase();
      if (lang.startsWith('en')) return v;
    }
    return voices.first;
  } catch (_) {
    return null;
  }
}

void playWizardBlipImpl({
  required double volume,
  required int wordIndex,
}) {}

void speakWizardTextImpl(
  String text, {
  required double volume,
  WordBoundaryCallback? onBoundary,
  void Function()? onComplete,
}) {
  final synth = _speechSynthesis;
  if (synth == null) return;
  try {
    synth.callMethod<JSAny?>('cancel'.toJS);
    final utterance = _SpeechSynthesisUtterance(text);
    utterance.lang = 'en-US';
    utterance.pitch = 1.25;
    utterance.rate = 1.15;
    utterance.volume = volume.clamp(0.0, 1.0);

    final voice = _pickWizardVoice(synth);
    if (voice != null) {
      utterance.voice = voice;
    }

    if (onBoundary != null) {
      utterance.onboundary = ((JSObject event) {
        final idx = event.getProperty<JSNumber?>('charIndex'.toJS)?.toDartInt;
        if (idx != null) {
          onBoundary(idx);
        }
      }).toJS;
    }
    if (onComplete != null) {
      utterance.onend = (() {
        onComplete();
      }).toJS;
      utterance.onerror = (() {
        onComplete();
      }).toJS;
    }

    synth.callMethod<JSAny?>('speak'.toJS, utterance);
  } catch (_) {}
}

void stopWizardSpeechImpl() {
  final synth = _speechSynthesis;
  if (synth == null) return;
  try {
    synth.callMethod<JSAny?>('cancel'.toJS);
  } catch (_) {}
}
