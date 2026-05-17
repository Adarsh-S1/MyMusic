import 'package:mymusic/domain/entities/song.dart';

/// Use case for playing a song (delegates to the player provider).
class PlaySongUsecase {
  /// Execute is handled by the PlayerNotifier directly.
  /// This use case exists for architecture completeness.
  void execute(Song song) {
    // The actual playback is controlled by PlayerNotifier.playSong()
    // This use case would wrap any additional business logic
    // (e.g., analytics, play count tracking, etc.)
  }
}
