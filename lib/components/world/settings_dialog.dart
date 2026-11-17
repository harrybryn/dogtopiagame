import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
import '../../services/audio_service.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class SettingsDialog extends StatefulWidget {
  final GameController game;

  const SettingsDialog({super.key, required this.game});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    return GenericModal(
      title: 'SETTINGS',
      maxWidth: 580,
      onClose: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                Row(
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
