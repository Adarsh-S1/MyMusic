import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search songs...', border: InputBorder.none),
                onChanged: _onSearchChanged,
              )
            : const Text('Library'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Playlists'),
            Tab(text: 'Artists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _SongsTab(),
          const _PlaylistsTab(),
          const _ArtistsTab(),
        ],
      ),
    );
  }
}

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final songsAsync = query.isEmpty ? ref.watch(libraryProvider) : ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.music_off, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('No songs yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Downloaded songs will appear here', style: theme.textTheme.bodySmall),
            ]),
          );
        }
        return ListView.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return Dismissible(
              key: Key(song.videoId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: theme.colorScheme.error,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Song'),
                    content: Text('Delete "${song.title}"? This will also remove the file.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                ref.read(libraryRepositoryProvider).deleteSong(song.videoId);
                ref.invalidate(libraryProvider);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "${song.title}"')));
              },
              child: ListTile(
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.music_note, color: theme.colorScheme.primary),
                ),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${song.artist ?? 'Unknown Artist'} • ${song.duration.toHumanString()}', style: theme.textTheme.bodySmall),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      ref.read(libraryRepositoryProvider).deleteSong(song.videoId);
                      ref.invalidate(libraryProvider);
                    } else if (value == 'queue') {
                      ref.read(playerProvider.notifier).addToQueue(song);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to queue')));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'queue', child: ListTile(leading: Icon(Icons.queue_music), title: Text('Add to queue'))),
                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: theme.colorScheme.error), title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)))),
                  ],
                ),
                onTap: () {
                  ref.read(playerProvider.notifier).playQueue(songs, index);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);
    final theme = Theme.of(context);

    return playlistsAsync.when(
      data: (playlists) {
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCreatePlaylistDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create Playlist'),
              ),
            ),
          ),
          Expanded(
            child: playlists.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.playlist_add, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('No playlists yet', style: theme.textTheme.titleMedium),
                  ]))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {},
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                              Icon(Icons.playlist_play, size: 36, color: theme.colorScheme.primary),
                              const Spacer(),
                              Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text('${playlist.songVideoIds.length} songs', style: theme.textTheme.bodySmall),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Playlist name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              ref.read(libraryRepositoryProvider).createPlaylist(controller.text);
              ref.invalidate(playlistsProvider);
              Navigator.pop(ctx);
            }
          }, child: const Text('Create')),
        ],
      ),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    return songsAsync.when(
      data: (songs) {
        final artistMap = <String, List<Song>>{};
        for (final song in songs) {
          final artist = song.artist ?? 'Unknown Artist';
          artistMap.putIfAbsent(artist, () => []).add(song);
        }
        final artists = artistMap.keys.toList()..sort();

        if (artists.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.person_off, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No artists yet', style: theme.textTheme.titleMedium),
          ]));
        }

        return ListView.builder(
          itemCount: artists.length,
          itemBuilder: (context, index) {
            final artist = artists[index];
            final artistSongs = artistMap[artist]!;
            return ExpansionTile(
              leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, child: Icon(Icons.person, color: theme.colorScheme.primary)),
              title: Text(artist),
              subtitle: Text('${artistSongs.length} songs'),
              children: artistSongs.map((song) => ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.duration.toHumanString()),
                onTap: () => ref.read(playerProvider.notifier).playSong(song),
              )).toList(),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
