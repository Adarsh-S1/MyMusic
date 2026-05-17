import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Fetches audio streams from YouTube.
class ExtractAudioStreamUsecase {
  final IDownloaderRepository _repository;

  ExtractAudioStreamUsecase(this._repository);

  Future<List<AudioStreamInfo>> execute(String videoId) {
    return _repository.getAudioStreams(videoId);
  }
}
