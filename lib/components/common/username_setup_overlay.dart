import 'package:flutter/material.dart';
import 'hover_scale.dart';

class UsernameSetupOverlay extends StatefulWidget {
  final ValueChanged<String> onConfirmUsername;

  const UsernameSetupOverlay({
    super.key,
    required this.onConfirmUsername,
  });

  @override
  State<UsernameSetupOverlay> createState() => _UsernameSetupOverlayState();
}

class _UsernameSetupOverlayState extends State<UsernameSetupOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final AnimationController _bobController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _bobController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Please enter at least 2 characters.');
      return;
    }
    if (name.length > 16) {
      setState(() => _errorText = 'Keep your name under 16 characters.');
      return;
    }
    widget.onConfirmUsername(name);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // Main Wooden/Parchment Card
                    Container(
                      margin: const EdgeInsets.only(top: 86),
                      padding: const EdgeInsets.fromLTRB(30, 102, 30, 26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFFBEB),
                            Color(0xFFFEF3C7),
                            Color(0xFFFDE68A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: const Color(0xFF78350F), width: 4.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xCC000000),
                            blurRadius: 36,
                            offset: Offset(0, 16),
                          ),
                          BoxShadow(
                            color: Color(0x66FBBF24),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title Ribbon
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: const Color(0xFFFBBF24), width: 2.2),
                            ),
                            child: const Text(
                              'NAME YOUR KEEPER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFFEF08A),
                                fontFamily: 'Lilita One',
                                fontSize: 22,
                                letterSpacing: 0.9,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'Welcome to Dogtopia! Enter your game username so we can save your island progress automatically on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.38,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Username TextField
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            maxLength: 16,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            onChanged: (_) {
                              if (_errorText != null) {
                                setState(() => _errorText = null);
                              }
                            },
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 20,
                              letterSpacing: 0.6,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter your username...',
                              hintStyle: TextStyle(
                                color: const Color(0xFF92400E)
                                    .withValues(alpha: 0.55),
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD97706), width: 2.4),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0F766E), width: 2.8),
                              ),
                            ),
                          ),

                          if (_errorText != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _errorText!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Start CTA
                          HoverScale(
                            scale: 1.06,
                            onTap: _submit,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 34, vertical: 13),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF34D399),
                                    Color(0xFF059669),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: const Color(0xFFFEF08A), width: 2.2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66064E3B),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'START MY ISLAND',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Lilita One',
                                  fontSize: 17.5,
                                  letterSpacing: 0.9,
                                  decoration: TextDecoration.none,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x80000000),
                                      offset: Offset(0, 1.5),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Floating Merlin the Dog Wizard on top
                    Positioned(
                      top: -20,
                      child: AnimatedBuilder(
                        animation: _bobController,
                        builder: (context, child) {
                          final t =
                              Curves.easeInOut.transform(_bobController.value);
                          return Transform.translate(
                            offset: Offset(0, -6 * t),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/ui/DogWizard.png',
                          width: 192,
                          height: 196,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
