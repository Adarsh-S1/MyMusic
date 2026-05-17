import 'package:mymusic/domain/entities/download_task.dart';

/// Video metadata fetched from YouTube before download.
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

/// Audio stream info from YouTube.
class AudioStreamInfo {
  final String url;
  final int bitrate;
  final String codec;
  final int sizeBytes;

  const AudioStreamInfo({
    required this.url,
    required this.bitrate,
    required this.codec,
    required this.sizeBytes,
  });
}

/// Abstract contract for the downloader repository.
abstract class IDownloaderRepository {
  /// Validates a YouTube URL and returns the video ID, or null if invalid.
  String? validateYoutubeUrl(String url);

  /// Fetches metadata for a YouTube video.
  Future<VideoMetadata> fetchVideoMetadata(String videoId);

  /// Gets available audio streams for a video.
  Future<List<AudioStreamInfo>> getAudioStreams(String videoId);

  /// Downloads audio, converts to MP3, embeds tags, saves to disk and DB.
  /// Emits progress updates via the returned stream.
  Stream<DownloadTask> downloadAudio({
    required String videoId,
    required VideoMetadata metadata,
    required AudioStreamInfo stream,
  });

  /// Cancels an active download.
  Future<void> cancelDownload(String taskId);
}
