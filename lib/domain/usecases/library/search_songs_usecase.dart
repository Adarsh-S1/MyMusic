import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/repositories/i_library_repository.dart';

/// Searches songs by title or artist with debounce support.
class SearchSongsUsecase {
  final ILibraryRepository _repository;

  SearchSongsUsecase(this._repository);

  Future<List<Song>> execute(String query) {
    return _repository.searchSongs(query);
  }
}
