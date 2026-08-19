import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Fetches video metadata from YouTube (via yt-dlp).
class FetchVideoMetadataUsecase {
  final IDownloaderRepository _repository;

  FetchVideoMetadataUsecase(this._repository);

  Future<VideoMetadata> execute(String videoId) {
    return _repository.fetchVideoMetadata(videoId);
  }
}
