import 'package:mymusic/domain/entities/song.dart';
import 'package:mymusic/domain/entities/playlist.dart';

/// Abstract contract for the local music library repository.
abstract class ILibraryRepository {
  /// Retrieves all songs from the local database.
  Future<List<Song>> getAllSongs();

  /// Retrieves a single song by its video ID.
  Future<Song?> getSongByVideoId(String videoId);

  /// Saves a song to the local database.
  Future<void> saveSong(Song song);

  /// Deletes a song by its video ID (removes file + DB record).
  Future<void> deleteSong(String videoId);

  /// Searches songs by title or artist.
  Future<List<Song>> searchSongs(String query);

  /// Watches the song list for reactive updates.
  Stream<List<Song>> watchAllSongs();

  // ─── Playlist operations ─────────────────────────────

  /// Retrieves all playlists.
  Future<List<Playlist>> getAllPlaylists();

  /// Creates a new playlist.
  Future<void> createPlaylist(String name);

  /// Adds a song to a playlist.
  Future<void> addSongToPlaylist(String playlistId, String videoId);

  /// Removes a song from a playlist.
  Future<void> removeSongFromPlaylist(String playlistId, String videoId);

  /// Deletes a playlist.
  Future<void> deletePlaylist(String playlistId);

  /// Gets songs for a specific playlist.
  Future<List<Song>> getSongsForPlaylist(String playlistId);
}
