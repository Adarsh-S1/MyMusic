import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/entities/playlist_entry.dart';

/// Video metadata fetched from YouTube (via yt-dlp) before or during download.
class VideoMetadata {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;

  const VideoMetadata({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
  });
}

/// Metadata for a YouTube playlist.
class PlaylistMetadata {
  final String playlistId;
  final String title;
  final String author;
  final List<VideoMetadata> videos;

  const PlaylistMetadata({
    required this.playlistId,
    required this.title,
    required this.author,
    required this.videos,
  });
}

/// Abstract contract for the downloader repository.
abstract class IDownloaderRepository {
  /// Validates a YouTube URL and returns the video ID, or null if invalid.
  String? validateYoutubeUrl(String url);

  /// Validates a YouTube URL and returns the playlist ID, or null if invalid.
  String? validateYoutubePlaylistUrl(String url);

  /// Fetches metadata for a YouTube video (powered by yt-dlp, no download).
  Future<VideoMetadata> fetchVideoMetadata(String videoId);

  /// Fetches metadata for a YouTube playlist.
  Future<PlaylistMetadata> fetchPlaylistMetadata(String playlistId);

  /// Downloads audio using yt-dlp. Stream selection is handled internally.
  /// Emits progress updates via the returned stream.
  Stream<DownloadTask> downloadAudioDirect({
    required String videoId,
    required String title,
    String? playlistName,
  });

  /// Cancels an active download.
  Future<void> cancelDownload(String taskId);

  /// Extracts the list of videos from a YouTube playlist URL.
  /// Returns (playlist title, list of PlaylistEntry).
  Future<(String, List<PlaylistEntry>)> fetchPlaylistVideos(String playlistUrl);
}
