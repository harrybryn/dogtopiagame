import 'dart:math';
import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
import '../../services/audio_service.dart';
import '../../services/local_save_service.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class SettingsDialog extends StatefulWidget {
  final GameController game;

  const SettingsDialog({super.key, required this.game});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _justSaved = false;

  Future<void> _handleManualSave() async {
    final ok = await LocalSaveService.instance.saveNow(widget.game);
    if (ok && mounted) {
      SoundManager.instance.playClick();
      setState(() => _justSaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justSaved = false);
      });
    }
  }

  void _openEditUsernameDialog() {
    final controller =
        TextEditingController(text: widget.game.playerUsername);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2),
        ),
        title: const Text(
          'CHANGE USERNAME',
          style: TextStyle(
            color: Color(0xFFFEF08A),
            fontFamily: 'Lilita One',
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Lilita One',
            fontSize: 16,
          ),
          decoration: const InputDecoration(
            counterStyle: TextStyle(color: Colors.white54),
            hintText: 'Enter username (2-16 chars)...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF59E0B)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFEF08A), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              final next = controller.text.trim();
              if (next.length >= 2 && next.length <= 16) {
                widget.game.setUsername(next);
                LocalSaveService.instance.saveNow(widget.game);
                if (mounted) setState(() {});
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF3B1404),
            ),
            child: const Text('SAVE',
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontFamily: 'Lilita One')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GenericModal(
      title: 'SETTINGS',
      maxWidth: 580,
      scrollable: true,
      onClose: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 0. Player Profile & Local Save Card ──
            _buildProfileSaveCard(),
            const SizedBox(height: 8),

            // ── 1. Sound Effects (SFX) Card with Integrated Adjuster ──
            _buildSettingCard(
              title: 'Sound Effects (SFX)',
              icon: Icons.volume_up_rounded,
              isOn: widget.game.sfxEnabled,
              onToggle: () {
                widget.game.toggleSfx();
                setState(() {});
              },
              hasSlider: true,
              volume: widget.game.sfxVolume,
              onVolumeChanged: (val) {
                widget.game.setSfxVolume(val);
                setState(() {});
              },
              onVolumeChangeEnd: (_) {
                SoundManager.instance.playClick();
              },
              accentColor: const Color(0xFFD97706),
            ),
            const SizedBox(height: 8),

            // ── 2. Music BGM Card with Integrated Adjuster ──
            _buildSettingCard(
              title: 'Music BGM',
              icon: Icons.music_note_rounded,
              isOn: widget.game.bgmEnabled,
              onToggle: () {
                widget.game.toggleBgm();
                setState(() {});
              },
              hasSlider: true,
              volume: widget.game.bgmVolume,
              onVolumeChanged: (val) {
                widget.game.setBgmVolume(val);
                setState(() {});
              },
              accentColor: const Color(0xFF059669),
            ),
            const SizedBox(height: 8),

            // ── 3. Island Grid Lines Card ──
            _buildSettingCard(
              title: 'Island Grid Lines',
              icon: Icons.grid_on_rounded,
              isOn: widget.game.gridVisible,
              onToggle: () {
                widget.game.toggleGrid();
                setState(() {});
              },
              hasSlider: false,
              volume: 0,
              onVolumeChanged: (_) {},
              accentColor: const Color(0xFFD97706),
            ),
            const SizedBox(height: 8),

            // ── 4. Dog Wizard Tutorial Replay Card ──
            _buildReplayTutorialCard(),
            const SizedBox(height: 10),

            // ── Version Footnote ──
            const Text(
              'Dogtopia Sanctuary · Version 1.0',
              style: TextStyle(
                color: Color(0xFF92400E),
                fontFamily: 'Lilita One',
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoogleConnectPreviewDialog() {
    SoundManager.instance.playClick();
    final name = widget.game.hasUsername ? widget.game.playerUsername : 'Keeper';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2.5),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'GOOGLE CLOUD SAVE',
              style: TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Your island "$name" (Level ${widget.game.level}) is currently auto-saved locally on this device.\n\nGoogle + Supabase Cloud Sync is ready to link once online saving is enabled!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFEF3C7),
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF3B1404),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'GOT IT',
              style: TextStyle(
                fontFamily: 'Lilita One',
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSaveCard() {
    final name = widget.game.hasUsername ? widget.game.playerUsername : 'Guest';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD97706), width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C78350F),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top Row: Keeper Avatar, Username, Edit & Save Now ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;

                final avatar = Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border:
                        Border.all(color: const Color(0xFF78350F), width: 1.8),
                  ),
                  child: const Icon(Icons.pets_rounded,
                      color: Color(0xFF3B1404), size: 20),
                );

                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFD97706), width: 1),
                          ),
                          child: Text(
                            'LVL ${widget.game.level}',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontFamily: 'Lilita One',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            'Auto-saved locally on this device',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final editButton = HoverScale(
                  scale: 1.06,
                  onTap: _openEditUsernameDialog,
                  child: Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x24B45309),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFD97706), width: 1.2),
                    ),
                    child: const Text(
                      'EDIT',
                      style: TextStyle(
                        color: Color(0xFF78350F),
                        fontFamily: 'Lilita One',
                        fontSize: 11,
                      ),
                    ),
                  ),
                );

                final saveButton = HoverScale(
                  scale: 1.06,
                  onTap: _handleManualSave,
                  child: Container(
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: _justSaved
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      _justSaved ? 'SAVED!' : 'SAVE NOW',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                );

                if (!compact) {
                  return Row(
                    children: [
                      avatar,
                      const SizedBox(width: 10),
                      Expanded(child: identity),
                      editButton,
                      const SizedBox(width: 6),
                      saveButton,
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 10),
                        Expanded(child: identity),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: editButton),
                        const SizedBox(width: 6),
                        Expanded(child: saveButton),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Bottom Banner: Beautiful Connect with Google Cloud Save UI ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3E1805), Color(0xFF260D02)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: Color(0x88FBBF24), width: 1.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_upload_rounded,
                        color: Color(0xFF67E8F9), size: 17),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'CLOUD ACCOUNT BACKUP',
                        style: TextStyle(
                          color: Color(0xFFFEF08A),
                          fontFamily: 'Lilita One',
                          fontSize: 12,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FBBF24),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0x99FBBF24), width: 1),
                      ),
                      child: const Text(
                        'NOT CONNECTED',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontFamily: 'Lilita One',
                          fontSize: 9.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Link your Google account to save your island online and play across devices.',
                  style: TextStyle(
                    color: Color(0xCCFEF3C7),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Tactile Elevated Google Sign-In Button
                HoverScale(
                  scale: 1.025,
                  onTap: _showGoogleConnectPreviewDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFFE5E7EB), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CustomPaint(painter: _GoogleLogoPainter()),
                        ),
                        const SizedBox(width: 11),
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Connect with Google',
                              maxLines: 1,
                              style: TextStyle(
                                color: Color(0xFF1F2937),
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CLOUD',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontFamily: 'Lilita One',
                              fontSize: 9.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplayTutorialCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1478350F),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/ui/DogWizard.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Dog Wizard Tutorial',
                    style: TextStyle(
                      color: Color(0xFF3B1404),
                      fontFamily: 'Lilita One',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          HoverScale(
            scale: 1.06,
            onTap: () {
              Navigator.of(context).pop();
              widget.game.restartWalkthrough();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x20000000),
                    offset: Offset(0, 1.5),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                'REPLAY',
                style: TextStyle(
                  color: Color(0xFFFEF08A),
                  fontFamily: 'Lilita One',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required String title,
    required IconData icon,
    required bool isOn,
    required VoidCallback onToggle,
    required bool hasSlider,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
    ValueChanged<double>? onVolumeChangeEnd,
    required Color accentColor,
  }) {
    final percent = (volume * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1478350F),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row: Icon, Title, and ON/OFF Pill Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: const Color(0xFFB45309), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HoverScale(
                  scale: 1.06,
                  onTap: onToggle,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: isOn
                          ? const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x20000000),
                          offset: Offset(0, 1.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Integrated Volume Slider (Only shown if ON and hasSlider) ──
          if (hasSlider)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState:
                  isOn ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtle divider inside the card
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFFE5C89E).withAlpha(120),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 14, right: 12, top: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          volume == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_down_rounded,
                          size: 16,
                          color: const Color(0xFF92400E),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accentColor,
                              inactiveTrackColor: const Color(0xFFE5D5C5),
                              thumbColor: const Color(0xFFFBBF24),
                              overlayColor: accentColor.withAlpha(35),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                                elevation: 2,
                              ),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: volume,
                              min: 0.0,
                              max: 1.0,
                              onChanged: onVolumeChanged,
                              onChangeEnd: onVolumeChangeEnd,
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 40),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF78350F),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFFBBF24), width: 0.8),
                          ),
                          child: Text(
                            '$percent%',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFFEF3C7),
                              fontFamily: 'Lilita One',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              secondChild: const SizedBox(width: double.infinity, height: 0),
            ),
        ],
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.21;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Top-left to top-right red arc
    canvas.drawArc(rect, -pi * 0.85, pi * 0.62, false, redPaint);
    // Left yellow arc
    canvas.drawArc(rect, pi * 0.68, pi * 0.47, false, yellowPaint);
    // Bottom green arc
    canvas.drawArc(rect, pi * 0.14, pi * 0.56, false, greenPaint);
    // Right blue arc
    canvas.drawArc(rect, -pi * 0.04, pi * 0.22, false, bluePaint);

    // Blue horizontal crossbar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.50,
        size.height * 0.41,
        size.width * 0.48,
        stroke * 0.92,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
