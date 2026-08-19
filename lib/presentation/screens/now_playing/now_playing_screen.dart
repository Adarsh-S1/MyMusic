import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final song = player.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('No song playing')),
      );
    }

    final hasThumbnail = File(song.localThumbnailPath).existsSync();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueueSheet(context, ref, player),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Song'),
                  content: Text(
                    'Delete "${song.title}"? This will also remove the file.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );

              if (shouldDelete == true && context.mounted) {
                await ref
                    .read(libraryRepositoryProvider)
                    .deleteSong(song.videoId);
                ref.invalidate(libraryProvider);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${song.title}"')),
                );

                ref
                    .read(playerProvider.notifier)
                    .removeFromQueue(player.currentIndex);
                if (ref.read(playerProvider).queue.isEmpty) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          if (hasThumbnail)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Image.file(
                File(song.localThumbnailPath),
                fit: BoxFit.cover,
                color: Colors.black54,
                colorBlendMode: BlendMode.darken,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.3),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Album Art
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasThumbnail
                        ? Image.file(
                            File(song.localThumbnailPath),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.music_note,
                              size: 100,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                  const Spacer(flex: 1),

                  // Song Info
                  Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist ?? 'Unknown Artist',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Seek Slider
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
                        player.duration.inMilliseconds.toDouble().clamp(
                          1,
                          double.infinity,
                        ),
                      ),
                      max: player.duration.inMilliseconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
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
                  const SizedBox(height: 16),

                  // Transport Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: player.isShuffled
                              ? theme.colorScheme.primary
                              : Colors.white70,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).toggleShuffle(),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).previous(),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                        ),
                        child: IconButton(
                          iconSize: 40,
                          icon: Icon(
                            player.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => ref
                              .read(playerProvider.notifier)
                              .togglePlayPause(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).next(),
                      ),
                      IconButton(
                        icon: Icon(
                          player.repeatMode == SongRepeatMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: player.repeatMode != SongRepeatMode.off
                              ? theme.colorScheme.primary
                              : Colors.white70,
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).cycleRepeatMode(),
                      ),
                    ],
                  ),
                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(
    BuildContext context,
    WidgetRef ref,
    PlayerState player,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Up Next',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${player.queue.length} songs',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: player.queue.length,
                  itemBuilder: (context, index) {
                    final song = player.queue[index];
                    final isCurrent = index == player.currentIndex;
                    return ListTile(
                      leading: isCurrent
                          ? Icon(
                              Icons.play_arrow,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(song.artist ?? 'Unknown', maxLines: 1),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => ref
                            .read(playerProvider.notifier)
                            .removeFromQueue(index),
                      ),
                      onTap: () => ref
                          .read(playerProvider.notifier)
                          .playQueue(player.queue, index),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
