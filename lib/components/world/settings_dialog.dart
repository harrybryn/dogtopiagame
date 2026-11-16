import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
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
      maxWidth: 500,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // SFX Toggle
          _buildToggleTile(
            title: 'Sound Effects (SFX)',
            icon: Icons.volume_up,
            isOn: widget.game.sfxEnabled,
            onToggle: () {
              widget.game.toggleSfx();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // BGM Toggle
          _buildToggleTile(
            title: 'Music BGM',
            icon: Icons.music_note,
            isOn: widget.game.bgmEnabled,
            onToggle: () {
              widget.game.toggleBgm();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // Grid Toggle
          _buildToggleTile(
            title: 'Island Grid Lines',
            icon: Icons.grid_on,
            isOn: widget.game.gridVisible,
            onToggle: () {
              widget.game.toggleGrid();
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          // Version Footnote
          const Text(
            'Dogtopia Sanctuary · Version 1.0',
            style: TextStyle(
              color: Color(0xFF92400E),
              fontFamily: 'Lilita One',
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required IconData icon,
    required bool isOn,
    required VoidCallback onToggle,
  }) {
    return HoverScale(
      scale: 1.03,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD97706), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A78350F),
              offset: Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFB45309), size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF3B1404),
                    fontFamily: 'Lilita One',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              ),
              child: Text(
                isOn ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Lilita One',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
