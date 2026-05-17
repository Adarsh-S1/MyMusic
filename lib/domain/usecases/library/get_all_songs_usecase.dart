import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_library_repository.dart';

/// Retrieves all songs from the local library.
class GetAllSongsUsecase {
  final ILibraryRepository _repository;

  GetAllSongsUsecase(this._repository);

  Future<List<Song>> execute() {
    return _repository.getAllSongs();
  }
}
