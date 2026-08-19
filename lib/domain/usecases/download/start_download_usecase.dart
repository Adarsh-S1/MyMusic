import 'package:mymusic/domain/entities/download_task.dart';
import 'package:mymusic/domain/repositories/i_downloader_repository.dart';

/// Starts a download and returns a stream of progress updates.
class StartDownloadUsecase {
  final IDownloaderRepository _repository;

  StartDownloadUsecase(this._repository);

  Stream<DownloadTask> execute({
    required String videoId,
    required String title,
    String? playlistName,
  }) {
    return _repository.downloadAudioDirect(
      videoId: videoId,
      title: title,
      playlistName: playlistName,
    );
  }
}
