import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import '../../providers/player_provider.dart' show RepeatMode;
import '../common/glass_icon_button.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool isShuffleEnabled;
  final VoidCallback onShuffleToggle;
  final RepeatMode? repeatMode;
  final bool? isRepeatEnabled;
  final VoidCallback onRepeatToggle;
  final Color accentColor;

  /// Liquid Glass look: SF Symbols-style glyphs with no backgrounds; a glass
  /// disc swells in behind a control while it's pressed, and shuffle/repeat
  /// sit on a glass disc while they're on. Active glyphs use [accentColor]
  /// as given.
  final bool glass;

  const PlaybackControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.isShuffleEnabled,
    required this.onShuffleToggle,
    this.repeatMode,
    this.isRepeatEnabled,
    required this.onRepeatToggle,
    this.accentColor = Colors.white,
    this.glass = false,
  });

  RepeatMode get _effectiveRepeatMode {
    if (repeatMode != null) return repeatMode!;
    if (isRepeatEnabled != null) {
      return isRepeatEnabled! ? RepeatMode.all : RepeatMode.off;
    }
    return RepeatMode.off;
  }

  @override
  Widget build(BuildContext context) {
    if (glass) return _buildGlass(context);
    final mode = _effectiveRepeatMode;
    final isRepeatActive = mode != RepeatMode.off;
    final IconData repeatIcon = mode == RepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;

    final themePrimary = Theme.of(context).colorScheme.primary;
    final effectiveActiveColor = (accentColor == Colors.white ||
            accentColor.computeLuminance() > 0.85)
        ? (themePrimary != Colors.white ? themePrimary : const Color(0xFFFA243C))
        : accentColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SecondaryControlButton(
          icon: Icons.shuffle_rounded,
          isActive: isShuffleEnabled,
          activeColor: effectiveActiveColor,
          onTap: onShuffleToggle,
        ),
        _MainControlButton(
          icon: Icons.skip_previous_rounded,
          size: 48,
          onTap: onPrevious,
        ),
        _PlayPauseButton(
          isPlaying: isPlaying,
          onTap: onPlayPause,
          size: 72,
        ),
        _MainControlButton(
          icon: Icons.skip_next_rounded,
          size: 48,
          onTap: onNext,
        ),
        _SecondaryControlButton(
          icon: repeatIcon,
          isActive: isRepeatActive,
          activeColor: effectiveActiveColor,
          onTap: onRepeatToggle,
        ),
      ],
    );
  }

  Widget _buildGlass(BuildContext context) {
    final mode = _effectiveRepeatMode;
    final isRepeatActive = mode != RepeatMode.off;
    final idle = Colors.white.withValues(alpha: 0.6);

    Widget toggle(IconData icon, bool active, VoidCallback onTap, String label) {
      return GlassIconButton(
        icon: icon,
        size: 40,
        iconSize: 19,
        persistent: active,
        color: active ? accentColor : idle,
        semanticLabel: label,
        onPressed: onTap,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        toggle(CupertinoIcons.shuffle, isShuffleEnabled, onShuffleToggle,
            'Shuffle'),
        GlassIconButton(
          icon: CupertinoIcons.backward_fill,
          size: 62,
          iconSize: 32,
          persistent: false,
          semanticLabel: 'Previous',
          onPressed: onPrevious,
        ),
        GlassIconButton(
          icon: isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
          size: 76,
          iconSize: 44,
          persistent: false,
          semanticLabel: isPlaying ? 'Pause' : 'Play',
          onPressed: onPlayPause,
        ),
        GlassIconButton(
          icon: CupertinoIcons.forward_fill,
          size: 62,
          iconSize: 32,
          persistent: false,
          semanticLabel: 'Next',
          onPressed: onNext,
        ),
        toggle(
            mode == RepeatMode.one
                ? CupertinoIcons.repeat_1
                : CupertinoIcons.repeat,
            isRepeatActive,
            onRepeatToggle,
            'Repeat'),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  const _PlayPauseButton({
    required this.isPlaying,
    required this.onTap,
    this.size = 72,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: widget.size * 0.6,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MainControlButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _MainControlButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  @override
  State<_MainControlButton> createState() => _MainControlButtonState();
}

class _MainControlButtonState extends State<_MainControlButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Icon(
          widget.icon,
          size: widget.size,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SecondaryControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _SecondaryControlButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
              child: Icon(
                icon,
                color: isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.45),
                size: 24,
              ),
            ),
            if (isActive)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
