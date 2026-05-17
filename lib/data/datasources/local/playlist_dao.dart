import 'package:isar/isar.dart';
import 'package:mymusic/data/models/playlist_model.dart';
import 'package:mymusic/domain/entities/playlist.dart';

/// Data access object for playlists using Isar.
class PlaylistDao {
  final Isar _isar;

  PlaylistDao(this._isar);

  /// Get all playlists.
  Future<List<Playlist>> getAllPlaylists() async {
    final models = await _isar.playlistModels
        .where()
        .sortByDateCreatedDesc()
        .findAll();
    return models.map(_toEntity).toList();
  }

  /// Create a new playlist.
  Future<void> createPlaylist(String name) async {
    final model = PlaylistModel()
      ..name = name
      ..dateCreated = DateTime.now()
      ..songVideoIds = [];
    await _isar.writeTxn(() async {
      await _isar.playlistModels.put(model);
    });
  }

  /// Add a song video ID to a playlist.
  Future<void> addSongToPlaylist(int playlistId, String videoId) async {
    await _isar.writeTxn(() async {
      final model = await _isar.playlistModels.get(playlistId);
      if (model != null && !model.songVideoIds.contains(videoId)) {
        model.songVideoIds = [...model.songVideoIds, videoId];
        await _isar.playlistModels.put(model);
      }
    });
  }

  /// Remove a song video ID from a playlist.
  Future<void> removeSongFromPlaylist(int playlistId, String videoId) async {
    await _isar.writeTxn(() async {
      final model = await _isar.playlistModels.get(playlistId);
      if (model != null) {
        model.songVideoIds = model.songVideoIds
            .where((id) => id != videoId)
            .toList();
        await _isar.playlistModels.put(model);
      }
    });
  }

  /// Delete a playlist by ID.
  Future<void> deletePlaylist(int playlistId) async {
    await _isar.writeTxn(() async {
      await _isar.playlistModels.delete(playlistId);
    });
  }

  /// Get a playlist by ID.
  Future<Playlist?> getPlaylistById(int playlistId) async {
    final model = await _isar.playlistModels.get(playlistId);
    return model != null ? _toEntity(model) : null;
  }

  // ─── Mappers ───────────────────────────────────────────

  Playlist _toEntity(PlaylistModel model) {
    return Playlist(
      id: model.id.toString(),
      name: model.name,
      dateCreated: model.dateCreated,
      songVideoIds: model.songVideoIds,
    );
  }
}
