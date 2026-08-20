import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mymusic/presentation/providers/providers.dart';

void showQueueSheet(BuildContext context) {
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
