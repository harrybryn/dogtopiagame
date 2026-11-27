import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/google_auth_service.dart';
import '../../state/game_controller.dart';
import 'hover_scale.dart';

/// Reusable Google 4-color 'G' logo painter according to Google Brand guidelines.
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.205;
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Blue arc (top-right & right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.75, 1.5, false, paint);

    // Green arc (bottom-right & bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.45, false, paint);

    // Yellow arc (bottom-left & left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.2, 1.5, false, paint);

    // Red arc (top-left & top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.7, 1.8, false, paint);

    // Blue horizontal bar in the center
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barHeight = stroke;
    final barWidth = size.width * 0.48;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - stroke * 0.1,
        center.dy - barHeight / 2,
        barWidth,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Google Logo convenient widget wrapper.
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: GoogleLogoPainter()),
    );
  }
}

/// Authentic, cross-platform Google Account Sign-In / Account Picker dialog.
class GoogleSignInDialog extends StatefulWidget {
  final GameController? game;
  final String? initialEmail;
  final String? initialName;

  const GoogleSignInDialog({
    super.key,
    this.game,
    this.initialEmail,
    this.initialName,
  });

  static Future<GoogleUserData?> show(
    BuildContext context, {
    GameController? game,
    String? initialEmail,
    String? initialName,
  }) {
    return showDialog<GoogleUserData>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => GoogleSignInDialog(
        game: game,
        initialEmail: initialEmail,
        initialName: initialName,
      ),
    );
  }

  @override
  State<GoogleSignInDialog> createState() => _GoogleSignInDialogState();
}

class _GoogleSignInDialogState extends State<GoogleSignInDialog> {
  bool _isCustomMode = false;
  bool _isConnecting = false;
  String _selectedAccountEmail = '';

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  String? _customError;

  @override
  void initState() {
    super.initState();
    final keeperName = widget.game != null && widget.game!.hasUsername
        ? widget.game!.playerUsername
        : (widget.initialName?.isNotEmpty == true ? widget.initialName! : 'Keeper');

    final cleanSlug = keeperName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
    final fallbackEmail = cleanSlug.isNotEmpty
        ? '$cleanSlug@gmail.com'
        : 'dogtopia.keeper@gmail.com';

    _selectedAccountEmail = widget.initialEmail?.isNotEmpty == true
        ? widget.initialEmail!
        : fallbackEmail;

    _nameController = TextEditingController(text: keeperName);
    _emailController = TextEditingController(text: _selectedAccountEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _connectWith(String name, String email) async {
    setState(() {
      _isConnecting = true;
      _customError = null;
    });
    SoundManager.instance.playClick();

    // Brief realistic authentication feedback
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final user = await GoogleAuthService.instance.connectAccount(
      email: email,
      displayName: name,
      game: widget.game,
    );

    if (mounted) {
      Navigator.of(context).pop(user);
    }
  }

  void _submitCustom() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      setState(() => _customError = 'Please enter your name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _customError = 'Please enter a valid Google email.');
      return;
    }
    _connectWith(name, email);
  }

  @override
  Widget build(BuildContext context) {
    final keeperName = widget.game != null && widget.game!.hasUsername
        ? widget.game!.playerUsername
        : (widget.initialName?.isNotEmpty == true ? widget.initialName! : 'Keeper');

    final primaryEmail = _selectedAccountEmail;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 30,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Google Branding
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
                child: Column(
                  children: [
                    const GoogleLogoWidget(size: 36),
                    const SizedBox(height: 14),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isCustomMode
                          ? 'Enter your Google credentials'
                          : 'Choose an account to continue to Dogtopia',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontFamily: 'Fredoka',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              if (_isConnecting)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(
                    children: const [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.2,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Connecting to Google Cloud Save...',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (!_isCustomMode)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary Recommended Account Option
                      _buildAccountTile(
                        avatarLetter: keeperName.isNotEmpty
                            ? keeperName[0].toUpperCase()
                            : 'G',
                        avatarColor: const Color(0xFF2563EB),
                        title: keeperName,
                        subtitle: primaryEmail,
                        onTap: () => _connectWith(keeperName, primaryEmail),
                      ),
                      const SizedBox(height: 8),

                      // Alternative Demo Account Option (Dogtopia Cloud)
                      _buildAccountTile(
                        avatarLetter: 'D',
                        avatarColor: const Color(0xFF059669),
                        title: 'Dogtopia Cloud Player',
                        subtitle: 'dogtopia.player@gmail.com',
                        onTap: () => _connectWith(
                          'Dogtopia Cloud Player',
                          'dogtopia.player@gmail.com',
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Use Another Account Button
                      HoverScale(
                        scale: 1.015,
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          SoundManager.instance.playClick();
                          setState(() => _isCustomMode = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB), width: 1.2),
                          ),
                          child: Row(
                            children: const [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFF3F4F6),
                                child: Icon(Icons.person_add_alt_1_rounded,
                                    color: Color(0xFF4B5563), size: 20),
                              ),
                              SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Use another Google account',
                                  style: TextStyle(
                                    color: Color(0xFF1F2937),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: Color(0xFF9CA3AF), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Custom Account Input Form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Display Name',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontFamily: 'Fredoka',
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Alex Rivera',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF2563EB), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Google Email',
                        style: TextStyle(
                          color: Color(0xFF374151),
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontFamily: 'Fredoka',
                          fontSize: 14.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. alex.rivera@gmail.com',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF2563EB), width: 2),
                          ),
                        ),
                      ),
                      if (_customError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _customError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isCustomMode = false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4B5563),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                              child: const Text('Back',
                                  style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _submitCustom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 11),
                              ),
                              child: const Text('Continue',
                                  style: TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Footer Note
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  children: [
                    const Text(
                      'To continue, Google will securely link your island save with your Google Account for cross-device cloud backup.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontFamily: 'Fredoka',
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4B5563),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile({
    required String avatarLetter,
    required Color avatarColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return HoverScale(
      scale: 1.015,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          color: Colors.white,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor,
              child: Text(
                avatarLetter,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Lilita One',
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9CA3AF), size: 14),
          ],
        ),
      ),
    );
  }
}
