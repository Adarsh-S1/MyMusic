import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _isLandscape = false;

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
            icon: Icon(isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () => _showQueueSheet(context, ref, player),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteSong(context, song, player, theme),
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
              child: isLandscape
                  ? _buildLandscapeLayout(song, hasThumbnail, player, theme)
                  : _buildPortraitLayout(song, hasThumbnail, player, theme),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSong(BuildContext context, Song song, PlayerState player, ThemeData theme) async {
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

    if (shouldDelete == true) {
      await ref.read(libraryRepositoryProvider).deleteSong(song.videoId);
      ref.invalidate(libraryProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${song.title}"')),
      );

      if (player.queue.length <= 1) {
        ref.read(playerProvider.notifier).stop();
        Navigator.pop(context);
      } else {
        ref.read(playerProvider.notifier).removeFromQueue(player.currentIndex);
      }
    }
  }

  Widget _buildAlbumArt(Song song, bool hasThumbnail, ThemeData theme, {double size = 280}) {
    return Container(
      width: size,
      height: size,
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
                size: size * 0.4,
                color: theme.colorScheme.primary,
              ),
            ),
    );
  }

  Widget _buildSongInfo(Song song, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }

  Widget _buildSlider(PlayerState player, ThemeData theme) {
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

  Widget _buildTransportControls(PlayerState player, ThemeData theme, {bool isLandscape = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: player.isShuffled ? theme.colorScheme.primary : Colors.white70,
          ),
          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
        ),
        if (isLandscape)
          IconButton(
            icon: const Icon(Icons.replay_10, color: Colors.white70),
            onPressed: () {
              final newPos = player.position - const Duration(seconds: 10);
              ref.read(playerProvider.notifier).seek(newPos < Duration.zero ? Duration.zero : newPos);
            },
          ),
        IconButton(
          icon: const Icon(
            Icons.skip_previous,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () => ref.read(playerProvider.notifier).previous(),
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
            onPressed: () => ref.read(playerProvider.notifier).togglePlayPause(),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.skip_next,
            color: Colors.white,
            size: 36,
          ),
          onPressed: () => ref.read(playerProvider.notifier).next(),
        ),
        if (isLandscape)
          IconButton(
            icon: const Icon(Icons.forward_30, color: Colors.white70),
            onPressed: () {
              final newPos = player.position + const Duration(seconds: 30);
              ref.read(playerProvider.notifier).seek(newPos > player.duration ? player.duration : newPos);
            },
          ),
        IconButton(
          icon: Icon(
            player.repeatMode == SongRepeatMode.one ? Icons.repeat_one : Icons.repeat,
            color: player.repeatMode != SongRepeatMode.off ? theme.colorScheme.primary : Colors.white70,
          ),
          onPressed: () => ref.read(playerProvider.notifier).cycleRepeatMode(),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(Song song, bool hasThumbnail, PlayerState player, ThemeData theme) {
    return Column(
      children: [
        const Spacer(flex: 1),
        _buildAlbumArt(song, hasThumbnail, theme, size: 280),
        const Spacer(flex: 1),
        _buildSongInfo(song, theme),
        const SizedBox(height: 32),
        _buildSlider(player, theme),
        const SizedBox(height: 16),
        _buildTransportControls(player, theme, isLandscape: false),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildLandscapeLayout(Song song, bool hasThumbnail, PlayerState player, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: _buildAlbumArt(song, hasThumbnail, theme, size: 200),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSongInfo(song, theme),
                    const SizedBox(height: 16),
                    _buildTransportControls(player, theme, isLandscape: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildSlider(player, theme),
        const SizedBox(height: 16),
      ],
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
          return Consumer(
            builder: (context, ref, child) {
              final player = ref.watch(playerProvider);
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
          );
        },
      ),
    );
  }
}
