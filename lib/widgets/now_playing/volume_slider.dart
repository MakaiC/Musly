import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../providers/player_provider.dart';
import '../common/thick_bar_slider.dart';

class VolumeSlider extends StatefulWidget {
  const VolumeSlider({super.key, this.glass = false});

  /// Liquid Glass look: SF Symbols-style speaker glyphs.
  final bool glass;

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double _systemVolume = 0.0;

  @override
  void initState() {
    super.initState();
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((volume) {
      if (mounted) setState(() => _systemVolume = volume);
    });
    VolumeController.instance.addListener((volume) {
      if (mounted && !_isDragging) {
        setState(() => _systemVolume = volume);
      }
    });
  }

  @override
  void dispose() {
    VolumeController.instance.removeListener();
    super.dispose();
  }

  void _onVolumeChanged(double val, PlayerProvider player) {
    if (player.isRemotePlayback) {
      player.setVolume(val);
    } else {
      VolumeController.instance.setVolume(val);
      player.setVolume(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isRemote = player.isRemotePlayback;
    final baseVolume = isRemote ? player.volume : _systemVolume;
    final currentVolume = _isDragging ? _dragValue : baseVolume;

    return Row(
      children: [
        Icon(
          widget.glass ? CupertinoIcons.speaker_fill : Icons.volume_mute_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ThickBarSlider(
            value: currentVolume,
            activeColor: Colors.white,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
            },
            onChanged: (val) {
              setState(() => _dragValue = val);
              _onVolumeChanged(val, player);
            },
            onChangeEnd: (val) {
              setState(() => _isDragging = false);
            },
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          widget.glass ? CupertinoIcons.speaker_3_fill : Icons.volume_up_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 20,
        ),
      ],
    );
  }
}
