import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class NowPlayingControls extends ConsumerWidget {
  final PlayerState player;
  final ThemeData theme;
  final bool isLandscape;

  const NowPlayingControls({
    super.key,
    required this.player,
    required this.theme,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Increase size slightly in landscape
    final double standardIconSize = isLandscape ? 32.0 : 24.0;
    final double skipIconSize = isLandscape ? 44.0 : 36.0;
    final double playIconSize = isLandscape ? 48.0 : 40.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: standardIconSize,
          icon: Icon(
            Icons.shuffle,
            color: player.isShuffled ? theme.colorScheme.primary : Colors.white70,
          ),
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
        ),
        if (isLandscape)
          IconButton(
            iconSize: standardIconSize,
            icon: const Icon(Icons.replay_10, color: Colors.white70),
            onPressed: () {
              final newPos = player.position - const Duration(seconds: 10);
              ref.read(playerProvider.notifier).seek(newPos < Duration.zero ? Duration.zero : newPos);
            },
          ),
        IconButton(
          iconSize: skipIconSize,
          icon: const Icon(
            Icons.skip_previous,
            color: Colors.white,
          ),
          onPressed: () => ref.read(playerProvider.notifier).previous(),
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          child: IconButton(
            iconSize: playIconSize,
            icon: Icon(
              player.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
          ),
        ),
        IconButton(
          iconSize: skipIconSize,
          icon: const Icon(
            Icons.skip_next,
            color: Colors.white,
          ),
          onPressed: () => ref.read(playerProvider.notifier).next(),
        ),
        if (isLandscape)
          IconButton(
            iconSize: standardIconSize,
            icon: const Icon(Icons.forward_30, color: Colors.white70),
            onPressed: () {
              final newPos = player.position + const Duration(seconds: 30);
              ref.read(playerProvider.notifier).seek(newPos > player.duration ? player.duration : newPos);
            },
          ),
        IconButton(
          iconSize: standardIconSize,
          icon: Icon(
            player.repeatMode == SongRepeatMode.one ? Icons.repeat_one : Icons.repeat,
            color: player.repeatMode != SongRepeatMode.off ? theme.colorScheme.primary : Colors.white70,
          ),
          onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
        ),
      ],
    );
  }
}
