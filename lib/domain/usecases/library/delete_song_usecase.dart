import 'package:mymusic/domain/repositories/i_library_repository.dart';

/// Deletes a song from the library (file + DB record).
class DeleteSongUsecase {
  final ILibraryRepository _repository;

  DeleteSongUsecase(this._repository);

  Future<void> execute(String videoId) {
    return _repository.deleteSong(videoId);
  }
}
