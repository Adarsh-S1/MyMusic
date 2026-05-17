import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// YouTube datasource using youtube_explode_dart.
/// This is the ONLY class that depends on the youtube_explode_dart package,
/// keeping the extraction logic isolated for easy swapping.
abstract class IYoutubeDatasource {
  Future<VideoMetadata> fetchMetadata(String videoId);
  Future<List<AudioStreamInfo>> getAudioStreams(String videoId);
  void dispose();
}

class YoutubeExplodeDatasource implements IYoutubeDatasource {
  final yt.YoutubeExplode _yte = yt.YoutubeExplode();

  @override
  Future<VideoMetadata> fetchMetadata(String videoId) async {
    try {
      final video = await _yte.videos.get(videoId);
      return VideoMetadata(
        videoId: videoId,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
        thumbnailUrl: video.thumbnails.highResUrl,
      );
    } catch (e) {
      throw Exception('Failed to fetch metadata: $e');
    }
  }

  @override
  Future<List<AudioStreamInfo>> getAudioStreams(String videoId) async {
    try {
      final manifest = await _yte.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.sortByBitrate();

      return audioStreams.map((stream) {
        return AudioStreamInfo(
          url: stream.url.toString(),
          bitrate: stream.bitrate.bitsPerSecond,
          codec: stream.codec.toString(),
          sizeBytes: stream.size.totalBytes,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get audio streams: $e');
    }
  }

  @override
  void dispose() {
    _yte.close();
  }
}
