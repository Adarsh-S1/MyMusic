import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/presentation/providers/providers.dart';
import 'package:mymusic/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:mymusic/presentation/widgets/song_thumbnail.dart';

/// Persistent mini player widget shown above the BottomNavigationBar.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final song = player.currentSong;

    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: player.duration.inMilliseconds > 0
                  ? player.position.inMilliseconds / player.duration.inMilliseconds
                  : 0,
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Album art
                  SongThumbnail(
                    thumbnailPath: song.localThumbnailPath,
                    width: 44,
                    height: 44,
                    borderRadius: 8,
                    iconSize: 22,
                  ),
                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          song.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
                  ),
                  // Next
                  IconButton(
                    icon: Icon(Icons.skip_next, color: theme.colorScheme.onSurface),
                    onPressed: player.hasNext ? () => ref.read(playerProvider.notifier).next() : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
