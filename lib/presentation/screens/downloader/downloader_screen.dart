import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/core/extensions/extensions.dart';
import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/presentation/providers/providers.dart';

class DownloaderScreen extends ConsumerStatefulWidget {
  const DownloaderScreen({super.key});

  @override
  ConsumerState<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends ConsumerState<DownloaderScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlController.text = data!.text!;
      ref.read(downloadFormProvider.notifier).onUrlChanged(data.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(downloadFormProvider);
    final queueLength = ref.watch(
      downloadQueueProvider.select((q) => q.length),
    );
    final hasDownloads = queueLength > 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Download')),
      body: CustomScrollView(
        slivers: [
          // ── Form section ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // URL Input
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'Paste YouTube Video or Playlist URL...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.content_paste),
                            onPressed: _pasteFromClipboard,
                            tooltip: 'Paste',
                          ),
                          if (_urlController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _urlController.clear();
                                ref
                                    .read(downloadFormProvider.notifier)
                                    .clearForm();
                              },
                            ),
                        ],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                    ),
                    onChanged: (url) {
                      ref.read(downloadFormProvider.notifier).onUrlChanged(url);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Loading State
                  if (formState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // Error State
                  if (formState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              formState.error!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Single Video Preview
                  if (formState.metadata != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              formState.metadata!.thumbnailUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formState.metadata!.title,
                                  style: theme.textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${formState.metadata!.author} • ${formState.metadata!.duration.toHumanString()}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(downloadQueueProvider.notifier)
                                        .enqueue(
                                          videoId: formState.videoId!,
                                          title: formState.metadata!.title,
                                        );
                                    _urlController.clear();
                                    ref
                                        .read(downloadFormProvider.notifier)
                                        .clearForm();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Added to queue'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download MP3'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Playlist Preview
                  if (formState.playlistTitle != null &&
                      formState.playlistEntries != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.queue_music, size: 40),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formState.playlistTitle!,
                                        style: theme.textTheme.titleMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${formState.playlistEntries!.length} videos',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                ref
                                    .read(downloadQueueProvider.notifier)
                                    .enqueuePlaylist(
                                      formState.playlistEntries!,
                                      formState.playlistTitle!,
                                    );
                                _urlController.clear();
                                ref
                                    .read(downloadFormProvider.notifier)
                                    .clearForm();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Added ${formState.playlistEntries!.length} songs to queue',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download All'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Downloads Queue ──────────────────────────────────
          if (hasDownloads) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    //         Row(
                    //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //           children: [
                    //             Text('Downloads', style: theme.textTheme.titleLarge),
                    //             TextButton(
                    //               onPressed: () => ref
                    //                   .read(downloadQueueProvider.notifier)
                    //                   .clearFinished(),
                    //               child: const Text('Clear Finished'),
                    //             ),
                    //           ],
                    //         ),

                    // "Retry All" button — only when queue is fully done and has failures
                    _RetryAllButton(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final taskId = ref.read(downloadQueueProvider)[index].id;
                  return _DownloadTaskTile(taskId: taskId);
                }, childCount: queueLength),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final String taskId;

  const _DownloadTaskTile({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch this specific task, completely preventing parent/list rebuilds on progress ticks
    final task = ref.watch(
      downloadQueueProvider.select((queue) {
        for (final t in queue) {
          if (t.id == taskId) return t;
        }
        return null;
      }),
    );

    if (task == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    String statusLabel;
    Color statusColor;

    switch (task.status) {
      case DownloadStatus.pending:
        statusLabel = 'Queued';
        statusColor = theme.colorScheme.onSurfaceVariant;
        break;
      case DownloadStatus.downloading:
        statusLabel = 'Downloading';
        statusColor = theme.colorScheme.primary;
        break;
      case DownloadStatus.processing:
        statusLabel = 'Processing';
        statusColor = theme.colorScheme.secondary;
        break;
      case DownloadStatus.completed:
        statusLabel = 'Completed';
        statusColor = Colors.green;
        break;
      case DownloadStatus.failed:
        statusLabel = 'Failed';
        statusColor = theme.colorScheme.error;
        break;
      case DownloadStatus.cancelled:
        statusLabel = 'Cancelled';
        statusColor = theme.colorScheme.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                if (task.thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      task.thumbnailUrl!,
                      width: 60,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 45,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 45,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title ?? task.youtubeUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                      // if (task.errorMessage != null)
                      //   Text(
                      //     task.errorMessage!,
                      //     style: TextStyle(
                      //       color: theme.colorScheme.error,
                      //       fontSize: 12,
                      //     ),
                      //     maxLines: 2,
                      //     overflow: TextOverflow.ellipsis,
                      //   ),
                    ],
                  ),
                ),
                // Retry button for failed tasks
                if (task.status == DownloadStatus.failed)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Retry',
                    onPressed: () {
                      ref
                          .read(downloadQueueProvider.notifier)
                          .retryTask(taskId);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a "Retry All Failed" button only when:
/// 1. The entire queue is done (every task is completed, failed, or cancelled)
/// 2. At least one task is in the failed state
/// Hidden when downloads are still active or all succeeded.
class _RetryAllButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);

    // Don't show if queue is empty
    if (queue.isEmpty) return const SizedBox.shrink();

    // Check if all tasks are in a terminal state
    final allDone = queue.every(
      (t) =>
          t.status == DownloadStatus.completed ||
          t.status == DownloadStatus.failed ||
          t.status == DownloadStatus.cancelled,
    );

    // Check if at least one is failed
    final hasFailed = queue.any((t) => t.status == DownloadStatus.failed);

    if (!allDone || !hasFailed) return const SizedBox.shrink();

    final failedCount = queue
        .where((t) => t.status == DownloadStatus.failed)
        .length;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            ref.read(downloadQueueProvider.notifier).retryAllFailed();
          },
          icon: const Icon(Icons.refresh),
          label: Text('Retry All Failed ($failedCount)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
