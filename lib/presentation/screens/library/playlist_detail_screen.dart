import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/presentation/providers/providers.dart';
import 'package:mymusic/presentation/widgets/song_thumbnail.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(playlistSongsProvider(playlistId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        actions: [
          IconButton(
            iconSize: 40,
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSongsDialog(context, ref),
            tooltip: 'Add Songs',
          ),
          IconButton(
            iconSize: 36,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeletePlaylist(context, ref),
            tooltip: 'Delete Playlist',
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.queue_music,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Playlist is empty', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showAddSongsDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Songs'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Padding(
              //   padding: const EdgeInsets.symmetric(vertical: 16.0),
              //   child: FilledButton.icon(
              //     onPressed: () =>
              //         ref.read(playerProvider.notifier).playQueue(songs, 0),
              //     icon: const Icon(Icons.play_arrow),
              //     label: const Text('Play All'),
              //   ),
              // ),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: SongThumbnail(
                        thumbnailPath: song.localThumbnailPath,
                        width: 48,
                        height: 48,
                        borderRadius: 8,
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${song.artist ?? 'Unknown Artist'} • ${song.duration.toHumanString()}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          await ref
                              .read(libraryRepositoryProvider)
                              .removeSongFromPlaylist(playlistId, song.videoId);
                          ref.invalidate(playlistSongsProvider(playlistId));
                          ref.invalidate(playlistsProvider);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(playerProvider.notifier)
                            .playQueue(songs, index);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: (songsAsync.valueOrNull?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () => ref
                  .read(playerProvider.notifier)
                  .playQueue(songsAsync.value!, 0),
              label: const Text('Play All'),
              icon: const Icon(Icons.play_arrow),
            )
          : null,
    );
  }

  void _confirmDeletePlaylist(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Are you sure you want to delete "$playlistName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(libraryRepositoryProvider)
                  .deletePlaylist(playlistId);
              ref.invalidate(playlistsProvider);
              if (ctx.mounted) Navigator.pop(ctx); // Close dialog
              if (context.mounted) Navigator.pop(context); // Go back to library
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSongsDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddSongsSheet(playlistId: playlistId),
    ).then((_) {
      // Invalidate the provider when the sheet closes to update the UI
      ref.invalidate(playlistSongsProvider(playlistId));
      ref.invalidate(playlistsProvider);
    });
  }
}

class _AddSongsSheet extends ConsumerStatefulWidget {
  final String playlistId;
  const _AddSongsSheet({required this.playlistId});

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  final Set<String> _selectedVideoIds = {};

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);
    final playlistSongsAsync = ref.watch(
      playlistSongsProvider(widget.playlistId),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Songs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: libraryAsync.when(
                data: (allSongs) {
                  return playlistSongsAsync.when(
                    data: (playlistSongs) {
                      final existingIds = playlistSongs
                          .map((s) => s.videoId)
                          .toSet();
                      // Only show songs not already in the playlist
                      final availableSongs = allSongs
                          .where((s) => !existingIds.contains(s.videoId))
                          .toList();

                      if (availableSongs.isEmpty) {
                        return const Center(
                          child: Text('No more songs to add.'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: availableSongs.length,
                        itemBuilder: (context, index) {
                          final song = availableSongs[index];
                          final isSelected = _selectedVideoIds.contains(
                            song.videoId,
                          );

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) async {
                              setState(() {
                                if (value == true) {
                                  _selectedVideoIds.add(song.videoId);
                                } else {
                                  _selectedVideoIds.remove(song.videoId);
                                }
                              });

                              // Add or remove immediately
                              if (value == true) {
                                await ref
                                    .read(libraryRepositoryProvider)
                                    .addSongToPlaylist(
                                      widget.playlistId,
                                      song.videoId,
                                    );
                              } else {
                                await ref
                                    .read(libraryRepositoryProvider)
                                    .removeSongFromPlaylist(
                                      widget.playlistId,
                                      song.videoId,
                                    );
                              }
                            },
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(song.artist ?? 'Unknown'),
                            secondary: const Icon(Icons.music_note),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );
      },
    );
  }
}
