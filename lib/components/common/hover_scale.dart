import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;
  final String? tooltip;
  final HitTestBehavior behavior;
  final bool enableSounds;

  const HoverScale({
    super.key,
    required this.child,
    this.scale = 1.06,
    this.onTap,
    this.tooltip,
    this.behavior = HitTestBehavior.deferToChild,
    this.enableSounds = true,
  });

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Widget content = MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        setState(() => _hovered = true);
        if (widget.enableSounds && widget.onTap != null) {
          SoundManager.instance.playHover();
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.enableSounds && widget.onTap != null) {
            SoundManager.instance.playClick();
          }
          widget.onTap?.call();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.94 : (_hovered ? widget.scale : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: widget.child,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}
