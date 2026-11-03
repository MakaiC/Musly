import 'package:flutter/material.dart';

import '../common/thick_bar_slider.dart';

class PlaybackProgressSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final Color accentColor;

  const PlaybackProgressSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  State<PlaybackProgressSlider> createState() => _PlaybackProgressSliderState();
}

class _PlaybackProgressSliderState extends State<PlaybackProgressSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final maxDuration = widget.duration.inMilliseconds.toDouble();
    final currentDuration =
        _isDragging ? _dragValue : widget.position.inMilliseconds.toDouble();

    final safeMax = maxDuration > 0 ? maxDuration : 1.0;
    final progress = (currentDuration / safeMax).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThickBarSlider(
          value: progress,
          activeColor: widget.accentColor,
          onChangeStart: (v) {
            setState(() {
              _isDragging = true;
              _dragValue = v * safeMax;
            });
          },
          onChanged: (v) {
            setState(() => _dragValue = v * safeMax);
          },
          onChangeEnd: (v) {
            setState(() => _isDragging = false);
            widget.onChanged(Duration(milliseconds: (v * safeMax).toInt()));
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(Duration(milliseconds: currentDuration.toInt())),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "-${_formatDuration(widget.duration - Duration(milliseconds: currentDuration.toInt()))}",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
