import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/presentation/providers/providers.dart';
import 'package:mymusic/presentation/widgets/song_thumbnail.dart';

import 'widgets/now_playing_controls.dart';
import 'widgets/now_playing_slider.dart';
import 'widgets/queue_bottom_sheet.dart';

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
            onPressed: () => showQueueSheet(context),
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
                  ? _buildLandscapeLayout(song, player, theme)
                  : _buildPortraitLayout(song, player, theme),
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

  Widget _buildAlbumArt(Song song, {double size = 280}) {
    return SongThumbnail(
      thumbnailPath: song.localThumbnailPath,
      width: size,
      height: size,
      borderRadius: 24,
      iconSize: size * 0.4,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
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

  Widget _buildPortraitLayout(Song song, PlayerState player, ThemeData theme) {
    return Column(
      children: [
        const Spacer(flex: 1),
        _buildAlbumArt(song, size: 280),
        const Spacer(flex: 1),
        _buildSongInfo(song, theme),
        const SizedBox(height: 32),
        NowPlayingSlider(player: player, theme: theme),
        const SizedBox(height: 16),
        NowPlayingControls(player: player, theme: theme, isLandscape: false),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildLandscapeLayout(Song song, PlayerState player, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: _buildAlbumArt(song, size: 200),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSongInfo(song, theme),
                    const SizedBox(height: 16),
                    NowPlayingControls(player: player, theme: theme, isLandscape: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        NowPlayingSlider(player: player, theme: theme),
        const SizedBox(height: 16),
      ],
    );
  }
}
