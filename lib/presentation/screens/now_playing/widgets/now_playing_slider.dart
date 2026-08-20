import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class NowPlayingSlider extends ConsumerWidget {
  final PlayerState player;
  final ThemeData theme;

  const NowPlayingSlider({
    super.key,
    required this.player,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 6,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 14,
            ),
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: Colors.white24,
            thumbColor: theme.colorScheme.primary,
          ),
          child: Slider(
            value: player.position.inMilliseconds.toDouble().clamp(
              0,
              player.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            ),
            max: player.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            onChanged: (v) => ref
                .read(playerProvider.notifier)
                .seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                player.position.toHumanString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                player.duration.toHumanString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
