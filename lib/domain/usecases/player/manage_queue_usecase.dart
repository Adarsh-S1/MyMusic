import 'package:mymusic/domain/entities/song.dart';

/// Use case for managing the playback queue.
class ManageQueueUsecase {
  /// Add a song to the queue.
  List<Song> addToQueue(List<Song> currentQueue, Song song) {
    return [...currentQueue, song];
  }

  /// Remove a song from the queue by index.
  List<Song> removeFromQueue(List<Song> currentQueue, int index) {
    if (index < 0 || index >= currentQueue.length) return currentQueue;
    return [...currentQueue]..removeAt(index);
  }

  /// Reorder the queue.
  List<Song> reorderQueue(List<Song> currentQueue, int oldIndex, int newIndex) {
    final list = [...currentQueue];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return list;
  }
}
