typedef WordBoundaryCallback = void Function(int charIndex);

void speakWizardTextImpl(
  String text, {
  required double volume,
  WordBoundaryCallback? onBoundary,
  void Function()? onComplete,
}) {}

void playWizardBlipImpl({
  required double volume,
  required int wordIndex,
}) {}

void stopWizardSpeechImpl() {}
