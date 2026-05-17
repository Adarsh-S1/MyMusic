import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final downloadQueue = ref.watch(downloadQueueProvider);
    final player = ref.watch(playerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text('YT-Groove'),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Download Card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: InkWell(
                    onTap: () => context.go('/download'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                            theme.colorScheme.tertiary.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.content_paste_go, color: theme.colorScheme.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Paste & Download', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Paste a YouTube URL to download audio', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ]),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Active Downloads
                if (downloadQueue.isNotEmpty) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Active Downloads', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => context.go('/download'), child: const Text('View all')),
                  ]),
                  ...downloadQueue.take(3).map((task) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircularProgressIndicator(value: task.progress),
                      title: Text(task.title ?? 'Downloading...', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('${(task.progress * 100).toInt()}%'),
                    ),
                  )),
                  const SizedBox(height: 20),
                ],

                // Continue Listening
                if (player.currentSong != null) ...[
                  Text('Continue Listening', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(width: 56, height: 56, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.music_note, color: theme.colorScheme.primary)),
                      title: Text(player.currentSong!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(player.currentSong!.artist ?? 'Unknown Artist'),
                      trailing: Icon(player.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 40, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Recently Downloaded
                libraryAsync.when(
                  data: (songs) {
                    if (songs.isEmpty) {
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: InkWell(
                          onTap: () => context.go('/download'),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(children: [
                              Icon(Icons.library_music_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text('Your library is empty', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Tap here to download your first song!', style: theme.textTheme.bodySmall),
                            ]),
                          ),
                        ),
                      );
                    }
                    final totalDuration = songs.fold<Duration>(Duration.zero, (prev, s) => prev + s.duration);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Recently Downloaded', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(onPressed: () => context.go('/library'), child: const Text('See all')),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: songs.take(10).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return GestureDetector(
                              onTap: () => ref.read(playerProvider.notifier).playSong(song),
                              child: Container(
                                width: 140,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: theme.colorScheme.surfaceContainerHigh),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Container(width: 80, height: 80, decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.music_note, size: 36, color: theme.colorScheme.primary)),
                                  const SizedBox(height: 12),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                                  const SizedBox(height: 4),
                                  Text(song.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            Column(children: [Icon(Icons.music_note, color: theme.colorScheme.primary, size: 28), const SizedBox(height: 8), Text('${songs.length}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text('Songs', style: theme.textTheme.bodySmall)]),
                            Column(children: [Icon(Icons.timer, color: theme.colorScheme.tertiary, size: 28), const SizedBox(height: 8), Text(totalDuration.toHumanString(), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text('Duration', style: theme.textTheme.bodySmall)]),
                          ]),
                        ),
                      ),
                    ]);
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
