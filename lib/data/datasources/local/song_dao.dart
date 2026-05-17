import 'package:isar/isar.dart';
import 'package:mymusic/data/models/song_model.dart';
import 'package:mymusic/domain/entities/song.dart';

/// Data access object for songs using Isar.
class SongDao {
  final Isar _isar;

  SongDao(this._isar);

  /// Get all songs, ordered by date added descending.
  Future<List<Song>> getAllSongs() async {
    final models = await _isar.songModels
        .where()
        .sortByDateAddedDesc()
        .findAll();
    return models.map(_toEntity).toList();
  }

  /// Get a song by its video ID.
  Future<Song?> getSongByVideoId(String videoId) async {
    final model = await _isar.songModels
        .where()
        .videoIdEqualTo(videoId)
        .findFirst();
    return model != null ? _toEntity(model) : null;
  }

  /// Save a song to the database.
  Future<void> saveSong(Song song) async {
    final model = _toModel(song);
    await _isar.writeTxn(() async {
      await _isar.songModels.put(model);
    });
  }

  /// Delete a song by video ID.
  Future<void> deleteSongByVideoId(String videoId) async {
    await _isar.writeTxn(() async {
      await _isar.songModels.deleteByVideoId(videoId);
    });
  }

  /// Search songs by title or artist.
  Future<List<Song>> searchSongs(String query) async {
    if (query.isEmpty) return getAllSongs();
    final lowerQuery = query.toLowerCase();
    final all = await getAllSongs();
    return all.where((song) {
      return song.title.toLowerCase().contains(lowerQuery) ||
          (song.artist?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Watch all songs reactively.
  Stream<List<Song>> watchAllSongs() {
    return _isar.songModels
        .where()
        .sortByDateAddedDesc()
        .watch(fireImmediately: true)
        .map((models) => models.map(_toEntity).toList());
  }

  // ─── Mappers ───────────────────────────────────────────

  Song _toEntity(SongModel model) {
    return Song(
      id: model.id.toString(),
      videoId: model.videoId,
      title: model.title,
      artist: model.artist,
      localAudioPath: model.localAudioPath,
      localThumbnailPath: model.localThumbnailPath,
      duration: Duration(milliseconds: model.durationMillis),
      dateAdded: model.dateAdded,
    );
  }

  SongModel _toModel(Song song) {
    return SongModel()
      ..videoId = song.videoId
      ..title = song.title
      ..artist = song.artist
      ..localAudioPath = song.localAudioPath
      ..localThumbnailPath = song.localThumbnailPath
      ..durationMillis = song.duration.inMilliseconds
      ..dateAdded = song.dateAdded;
  }
}
