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
    final downloadQueue = ref.watch(downloadQueueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Download')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // URL Input
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Paste YouTube URL here...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.content_paste), onPressed: _pasteFromClipboard, tooltip: 'Paste'),
                if (_urlController.text.isNotEmpty)
                  IconButton(icon: const Icon(Icons.clear), onPressed: () { _urlController.clear(); ref.read(downloadFormProvider.notifier).clearForm(); }),
              ]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
            ),
            onChanged: (url) => ref.read(downloadFormProvider.notifier).onUrlChanged(url),
          ),
          const SizedBox(height: 12),

          // Error message
          if (formState.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text(formState.error!, style: TextStyle(color: theme.colorScheme.error))),
              ]),
            ),

          // Loading indicator
          if (formState.isLoading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),

          // Metadata Preview Card
          if (formState.metadata != null) ...[
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Thumbnail placeholder + title
                  Row(children: [
                    Container(
                      width: 80, height: 60,
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.play_circle_outline, color: theme.colorScheme.primary, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(formState.metadata!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(formState.metadata!.author, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Text(formState.metadata!.duration.toHumanString(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ])),
                  ]),
                  const SizedBox(height: 16),
                  // Download button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (formState.audioStreams != null && formState.audioStreams!.isNotEmpty) {
                          ref.read(downloadQueueProvider.notifier).enqueue(
                            videoId: formState.videoId!,
                            metadata: formState.metadata!,
                            stream: formState.audioStreams!.first,
                          );
                          _urlController.clear();
                          ref.read(downloadFormProvider.notifier).clearForm();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started!')));
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download MP3'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],

          // Active Downloads List
          if (downloadQueue.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Downloads', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () => ref.read(downloadQueueProvider.notifier).clearFinished(), child: const Text('Clear finished')),
            ]),
            const SizedBox(height: 8),
            ...downloadQueue.map((task) => _DownloadTaskTile(task: task)),
          ],
        ],
      ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;
  const _DownloadTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = task.status == DownloadStatus.downloading || task.status == DownloadStatus.processing;

    IconData statusIcon;
    Color statusColor;
    switch (task.status) {
      case DownloadStatus.pending: statusIcon = Icons.hourglass_empty; statusColor = theme.colorScheme.onSurfaceVariant;
      case DownloadStatus.downloading: statusIcon = Icons.download; statusColor = theme.colorScheme.primary;
      case DownloadStatus.processing: statusIcon = Icons.settings; statusColor = theme.colorScheme.tertiary;
      case DownloadStatus.completed: statusIcon = Icons.check_circle; statusColor = Colors.green;
      case DownloadStatus.failed: statusIcon = Icons.error; statusColor = theme.colorScheme.error;
      case DownloadStatus.cancelled: statusIcon = Icons.cancel; statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title ?? task.youtubeUrl, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (task.status == DownloadStatus.downloading)
                Text('${task.formattedSpeed} • ${(task.progress * 100).toInt()}%', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (task.errorMessage != null)
                Text(task.errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            ])),
            if (isActive)
              IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(downloadQueueProvider.notifier).cancelDownload(task.id)),
          ]),
          if (isActive) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: task.status == DownloadStatus.processing ? null : task.progress, borderRadius: BorderRadius.circular(4)),
          ],
        ]),
      ),
    );
  }
}
