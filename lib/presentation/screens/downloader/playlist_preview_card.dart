import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/domain/entities/playlist_entry.dart';
import 'package:mymusic/presentation/providers/providers.dart';

/// A card that shows a playlist preview with individually selectable songs.
///
/// Each song is displayed as a card with its full title and a toggle button
/// to include/exclude it from the download. All songs are selected by default.
class PlaylistPreviewCard extends ConsumerStatefulWidget {
  final String playlistTitle;
  final List<PlaylistEntry> entries;
  final TextEditingController urlController;

  const PlaylistPreviewCard({
    super.key,
    required this.playlistTitle,
    required this.entries,
    required this.urlController,
  });

  @override
  ConsumerState<PlaylistPreviewCard> createState() =>
      _PlaylistPreviewCardState();
}

class _PlaylistPreviewCardState extends ConsumerState<PlaylistPreviewCard> {
  late Set<String> _selectedVideoIds;

  @override
  void initState() {
    super.initState();
    _selectedVideoIds =
        widget.entries.map((e) => e.videoId).toSet(); // all selected
  }

  @override
  void didUpdateWidget(PlaylistPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the playlist entries change (new URL pasted), reset selection
    if (oldWidget.entries != widget.entries) {
      _selectedVideoIds = widget.entries.map((e) => e.videoId).toSet();
    }
  }

  void _toggleSong(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        _selectedVideoIds.add(videoId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedVideoIds = widget.entries.map((e) => e.videoId).toSet();
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedVideoIds.clear();
    });
  }

  void _downloadSelected() {
    final selectedEntries = widget.entries
        .where((e) => _selectedVideoIds.contains(e.videoId))
        .toList();

    if (selectedEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs selected')),
      );
      return;
    }

    ref.read(downloadQueueProvider.notifier).enqueuePlaylist(
          selectedEntries,
          widget.playlistTitle,
        );
    widget.urlController.clear();
    ref.read(downloadFormProvider.notifier).clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${selectedEntries.length} songs to queue'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSelected =
        _selectedVideoIds.length == widget.entries.length;
    final noneSelected = _selectedVideoIds.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
            Row(
              children: [
                const Icon(Icons.queue_music, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.playlistTitle,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedVideoIds.length}/${widget.entries.length} selected',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Select All / Deselect All ───────────────
            Row(
              children: [
                TextButton.icon(
                  onPressed: allSelected ? null : _selectAll,
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('All'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: noneSelected ? null : _deselectAll,
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('None'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Song list ───────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.entries.length,
                itemBuilder: (context, index) {
                  final entry = widget.entries[index];
                  final isSelected =
                      _selectedVideoIds.contains(entry.videoId);
                  return _PlaylistSongTile(
                    entry: entry,
                    index: index,
                    isSelected: isSelected,
                    onToggle: () => _toggleSong(entry.videoId),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── Download button ─────────────────────────
            FilledButton.icon(
              onPressed:
                  _selectedVideoIds.isEmpty ? null : _downloadSelected,
              icon: const Icon(Icons.download),
              label: Text(
                'Download ${_selectedVideoIds.length} Songs',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single song tile within the playlist preview.
class _PlaylistSongTile extends StatelessWidget {
  final PlaylistEntry entry;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;

  const _PlaylistSongTile({
    required this.entry,
    required this.index,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Index number
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),

              // Song title — full name, no truncation
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration:
                        isSelected ? null : TextDecoration.lineThrough,
                    color: isSelected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Toggle icon
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.cancel_outlined,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
